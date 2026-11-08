package com.emoassistant.emo

import android.content.Context
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import com.google.mediapipe.tasks.genai.llminference.PromptTemplates
import java.io.File
import java.util.concurrent.Executors

/**
 * Runs one small language model entirely on the phone through MediaPipe.
 * Everything here is CPU-only so it behaves the same on emulators and
 * devices without a usable GPU delegate.
 */
object LocalLlm {
    val executor = Executors.newSingleThreadExecutor()

    private var engine: LlmInference? = null
    private var loadedModel: String? = null

    /** Where a bundled copy lives inside the APK. */
    private const val assetDir = "models"

    fun status(): Map<String, Any?> = synchronized(this) {
        mapOf(
            "loaded" to (engine != null),
            "model" to (loadedModel ?: "")
        )
    }

    /** The same model can ship inside the APK, at assets/models/<fileName>. */
    fun bundled(context: Context, fileName: String): Boolean {
        if (fileName.isBlank()) return false
        return try {
            context.assets.open("$assetDir/$fileName").use { }
            true
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * Copies the model out of the APK into the app's private folder so the
     * normal file-based loading path keeps working. A no-op when the file is
     * already there or this build carries no bundled model.
     */
    fun install(context: Context, fileName: String, bytes: Long): Map<String, Any?> {
        if (fileName.isBlank()) {
            return mapOf("ok" to false, "message" to "No model file was given.")
        }
        val modelsDir = File(context.filesDir, assetDir)
        val target = File(modelsDir, fileName)
        val expected = if (bytes > 0) (bytes * 0.98).toLong() else 0L
        val hasAsset = bundled(context, fileName)
        if (!hasAsset) {
            val enough = expected > 0 && target.length() >= expected
            return mapOf(
                "ok" to enough,
                "bundled" to false,
                "installed" to enough,
                "message" to if (enough) "Model ready" else "This build has no bundled model."
            )
        }
        if (expected > 0 && target.length() >= expected) {
            return mapOf(
                "ok" to true, "bundled" to true, "installed" to true,
                "message" to "Model ready"
            )
        }
        val partial = File(modelsDir, "$fileName.part")
        return try {
            if (!modelsDir.isDirectory) modelsDir.mkdirs()
            context.assets.open("$assetDir/$fileName").use { input ->
                partial.outputStream().use { output -> input.copyTo(output, 1 shl 20) }
            }
            if (target.exists()) target.delete()
            when {
                !partial.renameTo(target) -> {
                    partial.delete()
                    mapOf(
                        "ok" to false, "bundled" to true, "installed" to false,
                        "message" to "The model could not be moved into place."
                    )
                }
                expected > 0 && target.length() < expected -> {
                    target.delete()
                    mapOf(
                        "ok" to false, "bundled" to true, "installed" to false,
                        "message" to "The bundled model came through incomplete."
                    )
                }
                else -> mapOf(
                    "ok" to true, "bundled" to true, "installed" to true,
                    "message" to "Model installed from the app."
                )
            }
        } catch (t: Throwable) {
            try {
                partial.delete()
            } catch (_: Throwable) {
            }
            mapOf(
                "ok" to false, "bundled" to true, "installed" to false,
                "message" to (t.message ?: "The bundled model could not be installed.")
            )
        }
    }

    fun load(context: Context, path: String, maxTokens: Int): Map<String, Any?> {
        if (path.isBlank() || !File(path).isFile) {
            return mapOf("ok" to false, "message" to "The model file is missing.")
        }
        synchronized(this) {
            if (engine != null && loadedModel == path) {
                return mapOf("ok" to true, "message" to "Model already loaded")
            }
            releaseLocked()
        }
        return try {
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(path)
                .setMaxTokens(maxTokens.coerceIn(512, 4096))
                .setPreferredBackend(LlmInference.Backend.CPU)
                .build()
            val created = LlmInference.createFromOptions(context.applicationContext, options)
            synchronized(this) {
                engine = created
                loadedModel = path
            }
            mapOf("ok" to true, "message" to "Model loaded")
        } catch (t: Throwable) {
            mapOf(
                "ok" to false,
                "message" to (t.message ?: "The model could not be loaded")
            )
        }
    }

    fun generate(prompt: String): Map<String, Any?> {
        val current = synchronized(this) { engine }
            ?: return mapOf("ok" to false, "message" to "No on-device model is loaded.")
        return try {
            val options = LlmInferenceSession.LlmInferenceSessionOptions.builder()
                .setTopK(20)
                .setTopP(0.9f)
                .setTemperature(0.3f)
                .setRandomSeed(42)
                .setPromptTemplates(
                    PromptTemplates.builder()
                        .setUserPrefix("<|im_start|>user\n")
                        .setUserSuffix("<|im_end|>\n")
                        .setModelPrefix("<|im_start|>assistant\n")
                        .setModelSuffix("<|im_end|>\n")
                        .build()
                )
                .build()
            val session = LlmInferenceSession.createFromOptions(current, options)
            try {
                val started = System.currentTimeMillis()
                session.addQueryChunk(prompt)
                val text = session.generateResponse()
                mapOf(
                    "ok" to true,
                    "text" to text,
                    "ms" to (System.currentTimeMillis() - started)
                )
            } finally {
                try {
                    session.close()
                } catch (_: Throwable) {
                }
            }
        } catch (t: Throwable) {
            mapOf(
                "ok" to false,
                "message" to (t.message ?: "The model could not answer")
            )
        }
    }

    fun unload(): Map<String, Any?> {
        synchronized(this) { releaseLocked() }
        return mapOf("ok" to true, "message" to "Model unloaded")
    }

    private fun releaseLocked() {
        try {
            engine?.close()
        } catch (_: Throwable) {
        }
        engine = null
        loadedModel = null
    }
}
