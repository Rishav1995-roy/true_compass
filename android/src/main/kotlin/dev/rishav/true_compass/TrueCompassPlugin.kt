package dev.rishav.true_compass

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Streams raw rotation data. All heading maths (screen rotation, tilt blending,
 * declination, smoothing) lives in Dart where it is unit tested; this class only
 * forwards the rotation matrix, the display rotation and the sensor accuracy.
 */
class TrueCompassPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var context: Context
    private var sensorManager: SensorManager? = null
    private var sink: EventChannel.EventSink? = null
    private var listener: SensorEventListener? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        methods = MethodChannel(binding.binaryMessenger, "true_compass/methods")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "true_compass/events")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkAvailability", "requestPermission" ->
                result.success(if (hasSensor()) "available" else "noSensor")
            else -> result.notImplemented()
        }
    }

    private fun hasSensor(): Boolean {
        val sm = sensorManager ?: return false
        if (sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) != null) return true
        return sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null &&
            sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val sm = sensorManager
        if (sm == null || !hasSensor()) {
            events?.error("no_sensor", "No compass sensor on this device", null)
            return
        }
        val micros = ((arguments as? Map<*, *>)?.get("intervalMicros") as? Number)?.toInt() ?: 50_000
        // Ask the sensor hub for the requested rate; Dart throttles the rest.
        val delay = if (micros <= 0) SensorManager.SENSOR_DELAY_FASTEST else micros.coerceAtLeast(5_000)

        val rotation = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val l = if (rotation != null) rotationListener() else fallbackListener()
        listener = l
        if (rotation != null) {
            sm.registerListener(l, rotation, delay)
        } else {
            sm.registerListener(l, sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER), delay)
            sm.registerListener(l, sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD), delay)
        }
    }

    override fun onCancel(arguments: Any?) {
        stop()
    }

    private fun stop() {
        listener?.let { sensorManager?.unregisterListener(it) }
        listener = null
        sink = null
    }

    @Suppress("DEPRECATION")
    private fun displayRotationDegrees(): Int {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return 0
        return when (wm.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
    }

    private fun emit(map: Map<String, Any?>) {
        val s = sink ?: return
        if (Looper.myLooper() == Looper.getMainLooper()) s.success(map) else main.post { s.success(map) }
    }

    private fun matrixEvent(matrix: FloatArray, errorRadians: Float?): Map<String, Any?> {
        val error = if (errorRadians != null && errorRadians >= 0f)
            Math.toDegrees(errorRadians.toDouble()) else null
        return mapOf(
            "kind" to "matrix",
            "matrix" to matrix.map { it.toDouble() },
            "screenRotation" to displayRotationDegrees(),
            "errorDegrees" to error,
        )
    }

    private fun rotationListener() = object : SensorEventListener {
        private val matrix = FloatArray(9)
        override fun onSensorChanged(event: SensorEvent) {
            SensorManager.getRotationMatrixFromVector(matrix, event.values)
            // values[4] is the estimated heading accuracy in radians (-1 = unknown).
            val error = if (event.values.size >= 5) event.values[4] else null
            emit(matrixEvent(matrix, error))
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
            emit(mapOf("kind" to "accuracy", "status" to accuracy))
        }
    }

    /** Accelerometer + magnetometer, for the few devices without a rotation vector sensor. */
    private fun fallbackListener() = object : SensorEventListener {
        private val gravity = FloatArray(3)
        private val magnetic = FloatArray(3)
        private var haveGravity = false
        private var haveMagnetic = false
        private val matrix = FloatArray(9)

        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> {
                    System.arraycopy(event.values, 0, gravity, 0, 3); haveGravity = true
                }
                Sensor.TYPE_MAGNETIC_FIELD -> {
                    System.arraycopy(event.values, 0, magnetic, 0, 3); haveMagnetic = true
                }
            }
            if (haveGravity && haveMagnetic &&
                SensorManager.getRotationMatrix(matrix, null, gravity, magnetic)
            ) {
                emit(matrixEvent(matrix, null))
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
            if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) {
                emit(mapOf("kind" to "accuracy", "status" to accuracy))
            }
        }
    }
}
