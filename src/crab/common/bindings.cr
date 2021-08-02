lib LibSDL
  fun queue_audio = SDL_QueueAudio(dev : AudioDeviceID, data : Void*, len : UInt32) : Int
  fun get_queued_audio_size = SDL_GetQueuedAudioSize(dev : AudioDeviceID) : UInt32
  fun clear_queued_audio = SDL_ClearQueuedAudio(dev : AudioDeviceID)
  fun delay = SDL_Delay(ms : UInt32) : Nil
  fun get_ticks = SDL_GetTicks : UInt32
end

module SDL
  class Window
    def get_size : Tuple(Int32, Int32)
      LibSDL.get_window_size(@window, out w, out h)
      {w, h}
    end

    def width : Int32
      get_size[0]
    end

    def height : Int32
      get_size[1]
    end
  end
end
