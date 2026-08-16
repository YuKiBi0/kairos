package com.example.kairos

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val store = AndroidSecureCredentialStore(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kairos/secure_storage",
        ).setMethodCallHandler { call, result ->
            val key = call.argument<String>("key")
            if (key.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", "A credential key is required.", null)
                return@setMethodCallHandler
            }
            try {
                when (call.method) {
                    "write" -> {
                        val value = call.argument<String>("value")
                        if (value.isNullOrEmpty()) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "A credential value is required.",
                                null,
                            )
                        } else {
                            store.write(key, value)
                            result.success(null)
                        }
                    }

                    "read" -> result.success(store.read(key))
                    "delete" -> {
                        store.delete(key)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "SECURE_STORAGE_FAILED",
                    error.javaClass.simpleName,
                    null,
                )
            }
        }
    }
}

private class AndroidSecureCredentialStore(context: Context) {
    private val preferences = context.getSharedPreferences(
        "kairos_secure_credentials",
        Context.MODE_PRIVATE,
    )

    fun write(key: String, value: String) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        val payload = ByteBuffer.allocate(Int.SIZE_BYTES + cipher.iv.size + encrypted.size)
            .putInt(cipher.iv.size)
            .put(cipher.iv)
            .put(encrypted)
            .array()
        preferences.edit()
            .putString(key, Base64.encodeToString(payload, Base64.NO_WRAP))
            .apply()
    }

    fun read(key: String): String? {
        val encoded = preferences.getString(key, null) ?: return null
        val payload = ByteBuffer.wrap(Base64.decode(encoded, Base64.NO_WRAP))
        val ivSize = payload.int
        require(ivSize in 12..32) { "Invalid encrypted credential IV." }
        val iv = ByteArray(ivSize)
        payload.get(iv)
        val encrypted = ByteArray(payload.remaining())
        payload.get(encrypted)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(encrypted), StandardCharsets.UTF_8)
    }

    fun delete(key: String) {
        preferences.edit().remove(key).apply()
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) {
            return existing
        }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        private const val KEY_ALIAS = "kairos.refresh-token.v1"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
