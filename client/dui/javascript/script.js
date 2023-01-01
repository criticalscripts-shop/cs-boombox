const hash = window.location.hash ? window.location.hash.replace('#', '') : null
const hashData = hash ? hash.split('|') : []
const resourceName = hashData[0]
const uniqueId = hashData[1]
const urlCheckElement = document.createElement('input')
const lerp = (a, b, t) => (a * (1 - t)) + (b * t)

const gainLerpIntervalMs = 16.66
const playingInfoUpdateIntervalMs = 500

let activeInstance = null

class Speaker {
    constructor(id, options, manager) {
        this.id = id
        this.options = options
        this.manager = manager

        this.volumeMultiplier = this.options.volumeMultiplier
        this.distanceMultiplier = 1.0

        this.panner = this.manager.context.createPanner()
        this.gain = this.manager.context.createGain()

        this.gain.gain.value = 0.0

        this.gainLerp = {
            interval: null
        }

        this.panner.panningModel = 'HRTF'
        this.panner.distanceModel = 'exponential'
        this.panner.refDistance = this.options.refDistance
        this.panner.maxDistance = this.options.maxDistance
        this.panner.rolloffFactor = this.options.rolloffFactor
        this.panner.coneInnerAngle = this.options.coneInnerAngle
        this.panner.coneOuterAngle = this.options.coneOuterAngle
        this.panner.coneOuterGain = this.options.coneOuterGain

        this.manager.node.connect(this.panner)
        this.panner.connect(this.gain)
        this.gain.connect(this.manager.context.destination)

        this.twoDimensionalAudio = false
    }

    update(data) {
        this.panner.positionX.setValueAtTime(Math.round(data.position[0]), this.manager.context.currentTime + this.manager.timeDelta)
        this.panner.positionY.setValueAtTime(Math.round(data.position[1]), this.manager.context.currentTime + this.manager.timeDelta)
        this.panner.positionZ.setValueAtTime(Math.round(data.position[2]), this.manager.context.currentTime + this.manager.timeDelta)

        this.panner.orientationX.setValueAtTime(Math.round(data.orientation[0]), this.manager.context.currentTime + this.manager.timeDelta)
        this.panner.orientationY.setValueAtTime(Math.round(data.orientation[1]), this.manager.context.currentTime + this.manager.timeDelta)
        this.panner.orientationZ.setValueAtTime(Math.round(data.orientation[2]), this.manager.context.currentTime + this.manager.timeDelta)

        this.gain.gain.value = 0.75 * this.manager.volume * this.volumeMultiplier * (data.distance < this.options.refDistance ? 1.0 : (data.distance - this.options.refDistance) > this.options.maxDistance ? 0 : (1.0 - ((data.distance - this.options.refDistance) / this.options.maxDistance)))
    }
}

class MediaManager {
    constructor(uniqueId) {
        this.uniqueId = uniqueId
        this.playing = false

        this.syncedData = {
            playing: false,
            stopped: true,
            videoToggle: true,
            time: 0,
            volume: 0.0,
            url: null,
            temp: null
        }

        this.speakers = {}

        this.volume = 0.0

        this.context = new AudioContext()
        this.node = this.context.createGain()
        this.listener = this.context.listener

        this.timeDelta = 0.05

        this.controllers = {
            dummy: new DummyController(this, true)
        }

        this.controller = this.controllers.dummy

        setInterval(() => this.controllerPlayingInfo(this.controller), playingInfoUpdateIntervalMs)

        fetch(`https://${resourceName}/managerReady`, {
            method: 'POST',
            body: JSON.stringify({
                uniqueId: this.uniqueId
            })
        }).catch(error => {})

        document.title = ' '
    }

    controllerPlayingInfo(controller) {
        if (controller.key === this.controller.key && this.uniqueId)
            fetch(`https://${resourceName}/controllerPlayingInfo`, {
                method: 'POST',
                body: JSON.stringify({
                    uniqueId: this.uniqueId,
                    time: controller.time(),
                    duration: controller.duration,
                    playing: controller.playing
                })
            }).catch(error => {})
    }

    controllerHooked(controller) {
        if (controller.media)
            controller.media.connect(this.node)
    }

    controllerSeeked(controller) {
        if (controller.key === this.controller.key)
            fetch(`https://${resourceName}/controllerSeeked`, {
                method: 'POST',
                body: JSON.stringify({
                    uniqueId: this.uniqueId,
                    controller: controller.key
                })
            }).catch(error => {})
    }

    controllerError(controller, error) {
        if (controller.key === this.controller.key)
            fetch(`https://${resourceName}/controllerError`, {
                method: 'POST',
                body: JSON.stringify({
                    uniqueId: this.uniqueId,
                    controller: controller.key,
                    error
                })
            }).catch(error => {})
    }

    controllerEnded(controller) {
        if (controller.key === this.controller.key)
            fetch(`https://${resourceName}/controllerEnded`, {
                method: 'POST',
                body: JSON.stringify({
                    uniqueId: this.uniqueId,
                    controller: controller.key
                })
            }).catch(error => {})
    }

    controllerResync(controller) {
        if (controller.key === this.controller.key)
            fetch(`https://${resourceName}/controllerResync`, {
                method: 'POST',
                body: JSON.stringify({
                    uniqueId: this.uniqueId,
                    controller: controller.key
                })
            }).catch(error => {})
    }

    update(data) {
        for (let index = 0; index < data.speakers.length; index++)
            if (this.speakers[data.speakers[index].id])
                this.speakers[data.speakers[index].id].update(data.speakers[index])

        this.listener.upX.setValueAtTime(Math.round(data.listener.up[0]), this.context.currentTime + this.timeDelta)
        this.listener.upY.setValueAtTime(Math.round(data.listener.up[1]), this.context.currentTime + this.timeDelta)
        this.listener.upZ.setValueAtTime(Math.round(data.listener.up[2]), this.context.currentTime + this.timeDelta)

        this.listener.forwardX.setValueAtTime(Math.round(data.listener.forward[0]), this.context.currentTime + this.timeDelta)
        this.listener.forwardY.setValueAtTime(Math.round(data.listener.forward[1]), this.context.currentTime + this.timeDelta)
        this.listener.forwardZ.setValueAtTime(Math.round(data.listener.forward[2]), this.context.currentTime + this.timeDelta)

        this.listener.positionX.setValueAtTime(Math.round(data.listener.position[0]), this.context.currentTime + this.timeDelta)
        this.listener.positionY.setValueAtTime(Math.round(data.listener.position[1]), this.context.currentTime + this.timeDelta)
        this.listener.positionZ.setValueAtTime(Math.round(data.listener.position[2]), this.context.currentTime + this.timeDelta)
    }

    addSpeaker(id, options) {
        this.speakers[id] = new Speaker(id, options, this)
    }

    sync(data) {
        this.uniqueId = data.uniqueId

        this.set(data.url !== this.syncedData.url || data.temp.force, data.playing, data.url).then(() => {
            if (this.uniqueId !== data.uniqueId)
                return

            if ((data.stopped !== this.syncedData.stopped || data.temp.force) && data.stopped)
                this.stop()
            else if (data.playing !== this.syncedData.playing || data.temp.force) {
                this.play(true)

                if (data.playing)
                    this.play()
                else
                    this.pause()
            }

            if (data.volume !== this.syncedData.volume || data.temp.force)
                this.setVolume(data.volume)

            if (data.temp.seek || data.temp.force)
                this.seek(data.temp.force && data.duration ? (data.time + 1 > data.duration ? data.time : (data.time + 1)) : data.time)

            fetch(`https://${resourceName}/synced`, {
                method: 'POST',
                body: JSON.stringify({
                    uniqueId: this.uniqueId
                })
            }).catch(error => {})
        })
    }

    adjust(time) {
        if (this.controller.playing && Math.abs(Math.round(this.controller.time()) - Math.round(time)) >= 3)
            this.seek(time)
    }

    play(muted = false) {
        this.syncedData.playing = true
        this.syncedData.stopped = false
        this.controller.play(muted)
    }

    pause() {
        this.syncedData.playing = false
        this.controller.pause()
    }

    stop() {
        this.syncedData.playing = false
        this.syncedData.stopped = true
        this.syncedData.time = 0
        this.controller.stop()
    }

    seek(time) {
        this.syncedData.time = time
        this.controller.seek(time)
    }

    setVolume(volume) {
        this.syncedData.volume = volume
        this.volume = volume
    }

    set(state, playing, source) {
        return new Promise(async (resolve, reject) => {
            this.syncedData.url = source

            if ((!source) && state) {
                this.controller.set(null)
                resolve()
                return
            }

            let data = {
                key: 'dummy',
                source
            }

            urlCheckElement.value = source

            if (urlCheckElement.validity.valid) {
                const ytVideoId = source.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/i)
                const twitchChannel = source.match(/^(?:https?:\/\/)?(?:www\.|go\.)?twitch\.tv\/([A-z0-9_]+)($|\?)/i)
                const twitchVideo = source.match(/^(?:https?:\/\/)?(?:www\.|go\.)?twitch\.tv\/videos\/([0-9]+)($|\?)/i)
                const twitchClip = source.match(/(?:(?:^(?:https?:\/\/)?clips\.twitch\.tv\/([A-z0-9_-]+)(?:$|\?))|(?:^(?:https?:\/\/)?(?:www\.|go\.)?twitch\.tv\/(?:[A-z0-9_-]+)\/clip\/([A-z0-9_-]+)($|\?)))/)

                if (ytVideoId && ytVideoId[1])
                    data = {
                        key: 'youtube',
                        source: ytVideoId[1]
                    }
                else if (twitchChannel && twitchChannel[1])
                    data = {
                        key: 'twitch',
                        source: `channel:${twitchChannel[1]}`
                    }
                else if (twitchVideo && twitchVideo[1])
                    data = {
                        key: 'twitch',
                        source: `video:${twitchVideo[1]}`
                    }
                else if (twitchClip && (twitchClip[1] || twitchClip[2]))
                    data = {
                        key: 'frame',
                        source: `${source}&parent=${location.hostname}`
                    }
                else
                    data = {
                        key: 'frame',
                        source
                    }
            }

            if (this.controller.key === data.key) {
                this.controller.set(data.source)
                resolve()
            } else {
                if (state)
                    this.controller.set(null)
            
                const cb = (dummy = false) => {
                    const oldControllerKey = this.controller.key

                    if (dummy)
                        this.controller = this.controllers.dummy
                    else
                        this.controller = this.controllers[data.key]
                    
                    if (state || oldControllerKey !== this.controller.key)
                        this.controller.set(data.source)
    
                    resolve()
                }

                if (!this.controllers[data.key])
                    if (playing)
                        switch (data.key) {
                            case 'youtube':
                                this.controllers[data.key] = new YouTubeController(this, cb)
                                break

                            case 'twitch':
                                this.controllers[data.key] = new TwitchController(this, cb)
                                break
                            
                            case 'frame':
                                this.controllers[data.key] = new FrameController(this, cb)
                                break
                        }
                    else
                        cb(true)
                else
                    cb()
            }

            this.controllerPlayingInfo(this.controller)
        })
    }
}

window.addEventListener('message', event => {
    switch (event.data.type) {
        case 'cs-boombox:create':
            if (activeInstance)
                return

            activeInstance = new MediaManager(event.data.uniqueId)

            break

        case 'cs-boombox:update':
            if ((!activeInstance) || event.data.uniqueId !== activeInstance.uniqueId)
                return

            activeInstance.update({
                listener: event.data.listener,
                speakers: event.data.speakers
            })

            break

        case 'cs-boombox:addSpeaker':
            if ((!activeInstance) || event.data.uniqueId !== activeInstance.uniqueId)
                return

            activeInstance.addSpeaker(event.data.speakerId, {
                refDistance: event.data.refDistance,
                maxDistance: event.data.maxDistance,
                rolloffFactor: event.data.rolloffFactor,
                coneInnerAngle: event.data.coneInnerAngle,
                coneOuterAngle: event.data.coneOuterAngle,
                coneOuterGain: event.data.coneOuterGain,
                fadeDurationMs: event.data.fadeDurationMs,
                volumeMultiplier: event.data.volumeMultiplier
            })

            break

        case 'cs-boombox:sync':
            if ((!activeInstance) || event.data.uniqueId !== activeInstance.uniqueId)
                return

            activeInstance.sync({
                uniqueId: event.data.uniqueId,
                playing: event.data.playing,
                stopped: event.data.stopped,
                time: event.data.time,
                volume: event.data.volume,
                url: event.data.url,
                temp: event.data.temp,
                videoToggle: event.data.videoToggle
            })

            break

        case 'cs-boombox:adjust':
            if ((!activeInstance) || event.data.uniqueId !== activeInstance.uniqueId)
                return

            activeInstance.adjust(event.data.time)

            break
    }
})

urlCheckElement.setAttribute('type', 'url')

fetch(`https://${resourceName}/browserReady`, {
    method: 'POST',
    body: JSON.stringify({
        uniqueId
    })
}).catch(error => {})
