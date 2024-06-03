package com.example.pill_dispenser

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins
import com.polidea.rxandroidble2.exceptions.BleException

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        RxJavaPlugins.setErrorHandler { throwable: Throwable ->
            if (throwable is UndeliverableException && throwable.cause is BleException) {
                println("""Suppressed UndeliverableException: $throwable""")
                return@setErrorHandler   // ignore BleExceptions as they were surely delivered at least once
            }
            throw RuntimeException("Unexpected Throwable in RxJavaPlugins error handler", throwable)
        }
    }
}