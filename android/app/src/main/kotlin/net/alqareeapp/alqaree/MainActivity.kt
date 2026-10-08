package net.alqareeapp.alqaree

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service needs its own activity so background playback keeps one Flutter engine.
class MainActivity : AudioServiceActivity()
