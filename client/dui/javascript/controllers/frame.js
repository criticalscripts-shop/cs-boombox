class FrameController extends DummyController {
    constructor(manager, cb) {
        super(manager, false)

        this.key = 'frame'
        this.manager = manager
        this.context = this.manager.context

        this.element = null
        this.source = null
        this.duration = null
        this.media = null
        this.pending.pause = false
        this.pending.play = true
        this.pending.seek = null
        this.playing = false
        this.stopped = true
        this.hooked = false
        this.video = true

        this.canvas = document.createElement('canvas')
        this.frame = document.createElement('iframe')

        this.frame.id = 'frame-controller'
        this.frame.style.display = 'none'
        this.frame.seamless = true
        this.frame.src = 'about:blank'

        this.frame.addEventListener('load', () => {
            if (this.source && (!this.stopped))
                this.hook()
        })

        this.frame.addEventListener('error', () => this.manager.controllerError(this, 'E_SOURCE_ERROR'))

        document.body.appendChild(this.frame)
        this.ready = true
        setTimeout(() => cb(), 0)
    }

    hook() {
        this.frame.contentDocument.getElementsByTagName('html')[0].style = 'overflow: hidden !important'
        this.frame.contentDocument.getElementsByTagName('body')[0].style = 'overflow: hidden !important'

        const videos = this.frame.contentDocument.getElementsByTagName('video')
        const audios = this.frame.contentDocument.getElementsByTagName('audio')

        for (let index = 0; index < videos.length; index++) {
            videos[index].muted = true
            videos[index].pause()
        }

        for (let index = 0; index < audios.length; index++) {
            audios[index].muted = true
            audios[index].pause()
        }

        let element = videos[0]

        if (!element) {
            element = audios[0]
            this.video = false
        } else {
            this.video = false

            const sources = element.querySelectorAll('source')

            if (sources.length === 0)
                this.video = true
            else
                for (let index = 0; index < sources.length; index++)
                    if (sources[index].type.includes('video/')) {
                        this.video = true
                        break
                    }
        }

        if (!element) {
            this.manager.controllerError(this, 'E_SOURCE_NOT_FOUND')
            this.hooked = false
            this.video = false
            this.element = null
            this.stop()
            return
        }

        if (element !== this.element) {
            if (this.media)
                this.media.disconnect()

            this.element = element
            this.element.autoplay = false
            this.element.loop = false
            this.element.style = 'width:100%!important;height:100%!important;position:fixed!important;top:0!important;left:0!important;z-index:999999!important;background:black!important'
            this.element.pause()

            this.element.addEventListener('error', event => {
                this.manager.controllerError(this, 'E_SOURCE_ERROR')
                this.frame.style.display = 'none'

                if (this.element.ended && this.playing) {
                    this.playing = false
                    this.manager.controllerEnded(this)
                }

                if (this.element.paused)
                    this.playing = false
            })

            this.element.addEventListener('playing', event => {
                if (this.playing)
                    return

                this.element.muted = false
                this.playing = true

                if (this.pending.pause)
                    this.pause()

                if (this.pending.seek)
                    this.seek(this.pending.seek)

                if ((!this.duration) && this.element.duration)
                    this.duration = this.element.duration || -1
            })

            this.element.addEventListener('loadeddata', event => {
                if (!this.duration)
                    this.duration = this.element.duration || -1
            })

            this.element.addEventListener('durationchange', event => {
                if (!this.duration)
                    this.duration = this.element.duration || -1
            })

            this.element.addEventListener('seeked', event => this.seeked())
            this.element.addEventListener('ended', event => this.stop())

            this.media = this.context.createMediaElementSource(this.element)
            this.manager.controllerHooked(this)
        }

        this.hooked = true
        this.element.play().catch(e => {})
    }

    play(muted) {
        if (!this.source)
            return

        if (this.stopped) {
            this.stopped = false
            this.frame.src = this.source
        }

        if (this.hooked) {
            this.pending.play = false
            this.pending.pause = false
            this.element.muted = muted || this.pending.seek
            this.element.play().catch(e => {})
        } else {
            this.pending.pause = false
            this.pending.play = true
        }
    }

    pause() {
        if (!this.source)
            return

        if (this.playing) {
            this.element.pause()
            this.pending.play = false
            this.playing = false
        } else {
            this.pending.play = false
            this.pending.pause = true
        }
    }

    stop() {
        if (!this.source)
            return

        this.duration = null
        this.frame.style = 'display: none'
        this.seeked()

        this.stopped = true

        if (this.playing) {
            this.element.pause()
            this.element.currentTime = 0
            this.playing = false
            this.manager.controllerEnded(this)
        }

        this.pending.play = false
        this.pending.pause = false
        this.pending.seek = null

        this.video = false
        this.hooked = false
        this.element = null
        this.frame.src = 'about:blank'
    }

    seek(time) {
        if (!this.source)
            return
        
        this.seeking = true

        if (this.element) {
            this.pending.seek = null
            this.element.currentTime = time
            this.element.muted = false
        } else
            this.pending.seek = time
    }

    set(source) {
        if (source === this.source)
            return

        if (!source) {
            this.stop()
            this.source = null
            return
        }
    
        this.frame.style = 'display: none'

        if (this.playing) {
            this.element.pause()
            this.element.currentTime = 0
        }

        this.playing = false
        this.stopped = true

        this.source = source
        this.duration = null
        this.video = false
        this.hooked = false
        this.element = null
        this.frame.src = this.source
        this.seeked()
    }

    time() {
        return (this.source && this.ready && this.element && this.element.currentTime) || 0
    }
}
