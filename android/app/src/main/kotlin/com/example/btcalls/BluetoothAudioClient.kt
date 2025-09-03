package com.example.btcalls

import android.content.Context
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import java.io.IOException
import java.util.UUID
import kotlin.concurrent.thread

class BluetoothAudioClient(
    private val context: Context,
    private val eventCallback: (method: String, arg: Any?) -> Unit
) {
    private val SERVICE_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private var audioStreamer: AudioStreamer? = null
        private var connectedSocket: android.bluetooth.BluetoothSocket? = null

    fun startClient(mac: String) {
        thread {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                val device: BluetoothDevice = adapter.getRemoteDevice(mac)
                val socket: BluetoothSocket = device.createRfcommSocketToServiceRecord(SERVICE_UUID)
                adapter.cancelDiscovery()
                socket.connect()
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
        // Stop streaming and close socket
        audioStreamer?.stop()
        connectedSocket?.close()
    }
}
