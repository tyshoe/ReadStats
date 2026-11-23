package com.tyshoe.readstats

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors

/**
 * A folder the reader picked for automatic backups, through the system folder
 * picker (Storage Access Framework). Access is kept across restarts with a
 * persisted URI permission, and the folder outlives an uninstall.
 *
 * The folder's id is its tree URI; a file's ref is its document URI. File work
 * runs off the main thread. A folder that can no longer be reached — access
 * revoked, or the folder deleted — fails with code `no_access`.
 *
 * The same channel exists on iOS (AppDelegate.swift), so the Dart side is
 * shared.
 */
class BackupFolderChannel(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.tyshoe.readstats/backup_folder")
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private val resolver get() = activity.contentResolver

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "pick") {
            pick(result)
            return
        }
        val id = call.argument<String>("id")
        if (id == null) {
            result.error("bad_args", "No folder id", null)
            return
        }
        val tree = Uri.parse(id)
        when (call.method) {
            "check" -> background(result) { requireAccess(tree); folderName(tree) }
            "list" -> background(result) { requireAccess(tree); list(tree) }
            "write" -> background(result) {
                requireAccess(tree)
                write(
                    tree,
                    call.argument<String>("name")!!,
                    call.argument<String>("src")!!,
                    call.argument<String>("mime")!!,
                )
                null
            }
            "read" -> background(result) {
                requireAccess(tree)
                read(Uri.parse(call.argument<String>("ref")!!), call.argument<String>("dest")!!)
                null
            }
            "delete" -> background(result) {
                requireAccess(tree)
                DocumentsContract.deleteDocument(resolver, Uri.parse(call.argument<String>("ref")!!))
                null
            }
            "release" -> background(result) {
                try {
                    resolver.releasePersistableUriPermission(tree, ACCESS)
                } catch (_: SecurityException) {
                    // Already gone.
                }
                null
            }
            else -> result.notImplemented()
        }
    }

    // ─── Picking ────────────────────────────────────────────────────────────

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A folder is already being picked", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            .addFlags(ACCESS or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        try {
            activity.startActivityForResult(intent, REQUEST)
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.error("unavailable", "No folder picker on this device", null)
        }
    }

    /** Called by [MainActivity]; true when the result was the folder picker's. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        background(result) {
            resolver.takePersistableUriPermission(tree, ACCESS)
            mapOf("id" to tree.toString(), "name" to folderName(tree))
        }
        return true
    }

    // ─── Files ──────────────────────────────────────────────────────────────

    private fun folderDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun requireAccess(tree: Uri) {
        val granted = resolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission && it.isWritePermission
        }
        if (!granted) throw NoAccessException("Access to the backup folder was removed")
    }

    private fun folderName(tree: Uri): String {
        resolver.query(
            folderDocument(tree), arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        throw NoAccessException("The backup folder is gone")
    }

    private fun list(tree: Uri): List<Map<String, Any?>> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree, DocumentsContract.getTreeDocumentId(tree),
        )
        val columns = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_SIZE,
            Document.COLUMN_LAST_MODIFIED,
            Document.COLUMN_MIME_TYPE,
        )
        val files = mutableListOf<Map<String, Any?>>()
        val cursor = resolver.query(children, columns, null, null, null)
            ?: throw NoAccessException("The backup folder is gone")
        cursor.use {
            while (it.moveToNext()) {
                if (it.getString(4) == Document.MIME_TYPE_DIR) continue
                files.add(
                    mapOf(
                        "ref" to DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0)).toString(),
                        "name" to it.getString(1),
                        "size" to if (it.isNull(2)) null else it.getLong(2),
                        "modified" to if (it.isNull(3)) null else it.getLong(3),
                    ),
                )
            }
        }
        return files
    }

    /** Copies [src] into the folder as [name], over a file already called that. */
    private fun write(tree: Uri, name: String, src: String, mime: String) {
        val existing = list(tree).firstOrNull { it["name"] == name }?.get("ref") as String?
        val target = existing?.let(Uri::parse)
            ?: DocumentsContract.createDocument(resolver, folderDocument(tree), mime, name)
            ?: throw IOException("Couldn't create $name")
        val out = resolver.openOutputStream(target, "wt")
            ?: throw IOException("Couldn't write $name")
        out.use { stream -> File(src).inputStream().use { it.copyTo(stream, 1 shl 16) } }
    }

    private fun read(ref: Uri, dest: String) {
        val input = resolver.openInputStream(ref) ?: throw FileNotFoundException("Backup not found")
        input.use { stream -> FileOutputStream(dest).use { stream.copyTo(it, 1 shl 16) } }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: NoAccessException) {
                main.post { result.error("no_access", e.message, null) }
            } catch (e: SecurityException) {
                main.post { result.error("no_access", e.message, null) }
            } catch (e: IllegalArgumentException) {
                // A tree URI whose folder was deleted.
                main.post { result.error("no_access", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message ?: e.toString(), null) }
            }
        }
    }

    companion object {
        private const val REQUEST = 4711
        private const val ACCESS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }
}

/** The folder can't be reached: access was revoked, or it was deleted. */
class NoAccessException(message: String) : Exception(message)
