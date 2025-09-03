package com.example.btcalls

import android.content.Context
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import java.io.IOException
import java.util.UUID
import kotlin.concurrent.thread

class BluetoothAudioServer(
    private val context: Context,
    private val eventCallback: (method: String, arg: Any?) -> Unit
) {
    private val SERVICE_NAME = "BTCallsService"
    private val SERVICE_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private var serverSocket: BluetoothServerSocket? = null
        private var connectedSocket: android.bluetooth.BluetoothSocket? = null
        private var audioStreamer: AudioStreamer? = null

    fun startServer() {
        thread {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                serverSocket = adapter.listenUsingRfcommWithServiceRecord(SERVICE_NAME, SERVICE_UUID)
                eventCallback("onStatus", "listening")
                val socket = serverSocket!!.accept()
                serverSocket!!.close()
                eventCallback("onStatus", "connected")
                setupStreams(socket)
            } catch (e: IOException) {
                eventCallback("onError", e.message)
            }
        }
    }

    private fun setupStreams(socket: BluetoothSocket) {
        connectedSocket = socket
        audioStreamer = AudioStreamer(socket.inputStream, socket.outputStream)
        audioStreamer!!.start()
    }

    fun stop() {
        // Stop streaming and close sockets
        audioStreamer?.stop()
        connectedSocket?.close()
        serverSocket?.close()
    }
}
