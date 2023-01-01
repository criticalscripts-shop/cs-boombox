class DummyController {
    constructor(manager, ready) {
        this.key = 'dummy'
        this.playing = false
        this.seeking = false
        this.manager = manager
        
        this.pending = {
            stop: false,
            play: false,
            pause: false,
            seek: false
        }

        this.ready = ready
    }

    hook() {}

    play(muted) {}

    pause() {}

    stop() {}

    seek(time) {}

    set(source) {}

    time() {
        return null
    }

    seeked() {
        if (!this.seeking)
            return
        
        this.seeking = false
        this.manager.controllerSeeked(this)
    }
}
