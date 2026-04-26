package com.example.notevault

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterFragmentActivity() {
	private val channelName = "notevault/security"
	private val keyStoreProvider = "AndroidKeyStore"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				try {
					when (call.method) {
						"setSecureFlag" -> {
							window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
							result.success(true)
						}

						"ensureVaultKey" -> {
							val alias = call.requiredString("alias")
							ensureKey(alias)
							result.success(true)
						}

						"encrypt" -> {
							val alias = call.requiredString("alias")
							val plaintext = call.requiredString("plaintext")
							val encrypted = encrypt(alias, plaintext)
							result.success(encrypted)
						}

						"decrypt" -> {
							val alias = call.requiredString("alias")
							val encryptedBlob = call.requiredString("encryptedBlob")
							val decrypted = decrypt(alias, encryptedBlob)
							result.success(decrypted)
						}

						else -> result.notImplemented()
					}
				} catch (e: Exception) {
					result.error("SECURITY_ERROR", e.message, null)
				}
			}
	}

	private fun ensureKey(alias: String) {
		val keyStore = KeyStore.getInstance(keyStoreProvider).apply { load(null) }
		if (keyStore.containsAlias(alias)) {
			return
		}

		val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, keyStoreProvider)
		val keyGenParameterSpec =
			KeyGenParameterSpec.Builder(
				alias,
				KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
			)
				.setBlockModes(KeyProperties.BLOCK_MODE_GCM)
				.setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
				.setRandomizedEncryptionRequired(true)
				.build()
		keyGenerator.init(keyGenParameterSpec)
		keyGenerator.generateKey()
	}

	private fun getSecretKey(alias: String): SecretKey {
		ensureKey(alias)
		val keyStore = KeyStore.getInstance(keyStoreProvider).apply { load(null) }
		return keyStore.getKey(alias, null) as SecretKey
	}

	private fun encrypt(alias: String, plaintext: String): String {
		val cipher = Cipher.getInstance("AES/GCM/NoPadding")
		cipher.init(Cipher.ENCRYPT_MODE, getSecretKey(alias))
		val iv = cipher.iv
		val encryptedBytes = cipher.doFinal(plaintext.toByteArray(StandardCharsets.UTF_8))

		val packed = ByteBuffer.allocate(4 + iv.size + encryptedBytes.size)
			.putInt(iv.size)
			.put(iv)
			.put(encryptedBytes)
			.array()

		return Base64.encodeToString(packed, Base64.NO_WRAP)
	}

	private fun decrypt(alias: String, encryptedBlob: String): String {
		val packed = Base64.decode(encryptedBlob, Base64.NO_WRAP)
		val byteBuffer = ByteBuffer.wrap(packed)
		val ivSize = byteBuffer.int
		val iv = ByteArray(ivSize)
		byteBuffer.get(iv)

		val cipherBytes = ByteArray(byteBuffer.remaining())
		byteBuffer.get(cipherBytes)

		val cipher = Cipher.getInstance("AES/GCM/NoPadding")
		val spec = GCMParameterSpec(128, iv)
		cipher.init(Cipher.DECRYPT_MODE, getSecretKey(alias), spec)
		val decrypted = cipher.doFinal(cipherBytes)
		return String(decrypted, StandardCharsets.UTF_8)
	}

	private fun MethodCall.requiredString(name: String): String {
		val value = argument<String>(name)
		if (value.isNullOrBlank()) {
			throw IllegalArgumentException("$name is required")
		}
		return value
	}
}
