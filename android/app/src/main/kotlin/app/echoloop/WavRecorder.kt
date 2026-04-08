package app.echoloop

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * AudioRecord + WAV 文件录制模块。
 *
 * 职责：管理 AudioRecord 生命周期、将 PCM 数据写入 WAV 文件、
 * 计算每个 buffer 的 RMS 值（供外部 VAD 使用）。
 */
class WavRecorder {

    /** 每个 buffer 的 RMS 回调，在 IO 线程上调用。 */
    var onRms: ((Float) -> Unit)? = null

    private var audioRecord: AudioRecord? = null
    private var recordingJob: Job? = null
    private var wavFile: RandomAccessFile? = null
    private var currentFilePath: String? = null
    private var totalDataBytes: Int = 0

    /** 是否已初始化 AudioRecord。 */
    val isInitialized: Boolean get() = audioRecord != null

    companion object {
        private const val TAG = "WavRecorder"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BUFFER_SIZE_FRAMES = 1024
        private const val GAIN = 2.2f
        private const val BYTES_PER_SAMPLE = 2
        private const val NUM_CHANNELS = 1
    }

    /**
     * 初始化 AudioRecord 实例。不开始录音。
     * @return true 表示初始化成功。
     */
    fun initialize(): Boolean {
        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "AudioRecord.getMinBufferSize failed: $minBufferSize")
            return false
        }
        val bufferSize = max(minBufferSize, BUFFER_SIZE_FRAMES * BYTES_PER_SAMPLE)
        return try {
            val recorder = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize,
            )
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize, state=${recorder.state}")
                recorder.release()
                return false
            }
            audioRecord = recorder
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "RECORD_AUDIO permission not granted", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord init failed", e)
            false
        }
    }

    /**
     * 开始录音并写入 WAV 文件。
     * @param filePath WAV 输出路径。
     */
    fun startRecording(filePath: String) {
        val recorder = audioRecord ?: return
        currentFilePath = filePath
        totalDataBytes = 0

        val raf = RandomAccessFile(File(filePath), "rw")
        writeWavHeader(raf)
        wavFile = raf

        recorder.startRecording()

        recordingJob = CoroutineScope(Dispatchers.IO).launch {
            val buffer = ShortArray(BUFFER_SIZE_FRAMES)
            while (isActive) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read <= 0) continue

                val rms = computeRms(buffer, read)
                onRms?.invoke(rms)

                applyGainAndWrite(buffer, read)
            }
        }
    }

    /**
     * 停止录音，回填 WAV 头中的文件大小。
     * @return 录音文件路径。
     */
    fun stopRecording(): String? {
        recordingJob?.cancel()
        recordingJob = null

        try {
            audioRecord?.stop()
        } catch (e: IllegalStateException) {
            Log.w(TAG, "AudioRecord.stop() failed", e)
        }

        patchWavHeader()
        wavFile?.close()
        wavFile = null

        return currentFilePath
    }

    /** 释放 AudioRecord 和所有资源。 */
    fun release() {
        recordingJob?.cancel()
        recordingJob = null

        try {
            audioRecord?.stop()
        } catch (_: IllegalStateException) {
            // 可能还没 start，忽略。
        }
        audioRecord?.release()
        audioRecord = null

        wavFile?.close()
        wavFile = null
        currentFilePath = null
        onRms = null
    }

    /** 计算 16bit PCM buffer 的 RMS（归一化到 0.0~1.0）。 */
    private fun computeRms(buffer: ShortArray, length: Int): Float {
        if (length <= 0) return 0f
        var sum = 0.0
        for (i in 0 until length) {
            val normalized = buffer[i].toDouble() / Short.MAX_VALUE
            sum += normalized * normalized
        }
        return sqrt(sum / length).toFloat()
    }

    /** 对 buffer 应用增益并写入 WAV 文件。 */
    private fun applyGainAndWrite(buffer: ShortArray, length: Int) {
        val raf = wavFile ?: return
        val byteBuffer = ByteArray(length * BYTES_PER_SAMPLE)
        for (i in 0 until length) {
            val amplified = (buffer[i] * GAIN).toInt()
            val clamped = max(Short.MIN_VALUE.toInt(), min(Short.MAX_VALUE.toInt(), amplified))
            // WAV 使用 little-endian。
            byteBuffer[i * 2] = (clamped and 0xFF).toByte()
            byteBuffer[i * 2 + 1] = (clamped shr 8 and 0xFF).toByte()
        }
        try {
            raf.write(byteBuffer)
            totalDataBytes += byteBuffer.size
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write WAV data", e)
        }
    }

    /** 写 44 字节 RIFF/WAV 头（data size 用占位值）。 */
    private fun writeWavHeader(raf: RandomAccessFile) {
        val byteRate = SAMPLE_RATE * NUM_CHANNELS * BYTES_PER_SAMPLE
        val blockAlign = NUM_CHANNELS * BYTES_PER_SAMPLE

        raf.writeBytes("RIFF")
        raf.writeIntLE(0) // 文件总大小占位
        raf.writeBytes("WAVE")

        // fmt 子块
        raf.writeBytes("fmt ")
        raf.writeIntLE(16) // PCM fmt chunk size
        raf.writeShortLE(1) // PCM format
        raf.writeShortLE(NUM_CHANNELS)
        raf.writeIntLE(SAMPLE_RATE)
        raf.writeIntLE(byteRate)
        raf.writeShortLE(blockAlign)
        raf.writeShortLE(BYTES_PER_SAMPLE * 8)

        // data 子块
        raf.writeBytes("data")
        raf.writeIntLE(0) // data size 占位
    }

    /** 回填 WAV 头中的文件总大小和 data chunk 大小。 */
    private fun patchWavHeader() {
        val raf = wavFile ?: return
        try {
            // data chunk size at byte 40
            raf.seek(40)
            raf.writeIntLE(totalDataBytes)
            // RIFF chunk size at byte 4
            raf.seek(4)
            raf.writeIntLE(36 + totalDataBytes)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to patch WAV header", e)
        }
    }
}

/** 以 little-endian 写入 4 字节整数。 */
private fun RandomAccessFile.writeIntLE(value: Int) {
    write(value and 0xFF)
    write(value shr 8 and 0xFF)
    write(value shr 16 and 0xFF)
    write(value shr 24 and 0xFF)
}

/** 以 little-endian 写入 2 字节短整数。 */
private fun RandomAccessFile.writeShortLE(value: Int) {
    write(value and 0xFF)
    write(value shr 8 and 0xFF)
}
