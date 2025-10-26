package com.Kohnqueror.BrewLog // (or whatever your package name is)

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterFragmentActivity() {
    // This is required for plugins to work
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}