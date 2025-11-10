require 'rubygems'
require 'gosu'

module ZOrder
  BACKGROUND, MIDDLE, TOP = *0..2
end


#class representing a music track
class Track
  attr_accessor :name, :file
  def initialize(name, file)
    @name = name.strip
    @file = File.join(__dir__, "media", file.strip)
  end
end

#class representing an album
class Album
  attr_accessor :title, :artist, :artwork, :tracks, :year, :genre
  def initialize(title, artist, artwork, tracks, year, genre)
    @title = title.strip
    @artist = artist.strip
    @artwork = artwork.strip
    @tracks = tracks
    @year = year.strip
    @genre = genre.strip
  end
end

def read_track(file); Track.new(file.gets.strip, file.gets.strip); end

def read_tracks(file)
  count = file.gets.to_i
  Array.new(count) { read_track(file) }
end

#read album data and tracks
def read_album(file)
  Album.new(file.gets.strip, file.gets.strip, file.gets.strip, read_tracks(file), file.gets.strip, file.gets.strip)
end

#open file and read all albums
def read_albums(filename)
  File.open(filename, 'r') { |f| Array.new(f.gets.to_i) { read_album(f) } }
end

#music player window
class MusicPlayer < Gosu::Window
  def initialize(albums)
    # window settings
    @win_width = 1100
    @win_height = 600
    @album_size = 200
    @album_spacing_x = 250
    @album_spacing_y = 250

    super 1500, 600
    self.caption = "Ruby GUI Music Player"

    #position of buttons
    @button_y = @win_height - 60
    
    #store albums and their states
    @albums = albums
    @album_positions = []
    @album_hover = Array.new(@albums.size, false)
    @selected_album_index = nil
    @current_song = nil
    @now_playing = ""       #name of track currently playing

    @albums_per_page = 4      #show 4 albums per page (2x2 grid)
    @current_page = 0
    @total_pages = (@albums.length.to_f / @albums_per_page).ceil
    
    #fonts
    @font = Gosu::Font.new(20)
    @small_font = Gosu::Font.new(16)

    #stop/play button
    @stop_button_hover = false
    @stop_button_x = 500
    @stop_button_y = @button_y
    @stop_button_width = 120
    @stop_button_height = 35

    #track navigation buttons
    @is_paused = false
    #@current_track_index = nil
    @track_history = []
    @track_history_index = nil
    
    @track_button_width = 120
    @track_button_height = 35

    @prev_track_x = 630
    @next_track_x = 760
    @track_button_y = @button_y

    @prev_track_hover = false
    @next_track_hover = false

    #playlist button
    @playlist = []
    @show_playlist = false

    @playlist_button_x = 890
    @playlist_button_y = @button_y
    @playlist_button_width = 120
    @playlist_button_height = 35

    @playlist_action_y = 265
    @playlist_action_width = 110
    @playlist_action_height = 35

    #queue button
    @queue = []             # list of tracks to play next
    @current_queue_index = 0

    @queue_button_x = 1020 
    @queue_button_y = @button_y
    @queue_button_width = 120
    @queue_button_height = 35
    @queue_button_hover = false   
    @show_queue = false

    #history button
    @history_button_x = 1150
    @history_button_y = @button_y
    @history_button_width = 120
    @history_button_height = 35
    @history_button_hover = false
    @show_history = false

    #create artworks for ALL albums including playlist
    @artworks = @albums.map do |a|
      path = File.join(__dir__, "media", a.artwork)
      if File.exist?(path)
        Gosu::Image.new(path)
      else
        #fallback image if artwork not found
        Gosu::Image.from_blob(@album_size, @album_size, "\x1e\x1e\x1e\xff" * @album_size * @album_size)
      end
    end

  end

  #main draw method
  def draw
    Gosu.draw_rect(0, 0, 1500, @win_height, Gosu::Color.new(30, 30, 30), ZOrder::BACKGROUND)
    draw_albums
    draw_tracks
    draw_now_playing
    draw_page_buttons  
  end

  #draw album artwork grid with hover outlines
  def draw_albums
    start_index = @current_page * @albums_per_page
    0.upto(@albums_per_page - 1) do |idx|
      col = idx % 2
      row = idx / 2
      x = 20 + col * @album_spacing_x
      y = 20 + row * @album_spacing_y
      global_index = start_index + idx

      if global_index < @albums.size
        img = @artworks[global_index]
        scale_x = @album_size.to_f / img.width
        scale_y = @album_size.to_f / img.height
        img.draw(x, y, ZOrder::MIDDLE, scale_x, scale_y)

        #draw hover outline in red
        if @album_hover[global_index]
          outline_thickness = 4
          Gosu.draw_rect(x, y, @album_size, outline_thickness, Gosu::Color::RED, ZOrder::TOP)
          Gosu.draw_rect(x, y + @album_size - outline_thickness, @album_size, outline_thickness, Gosu::Color::RED, ZOrder::TOP)
          Gosu.draw_rect(x, y, outline_thickness, @album_size, Gosu::Color::RED, ZOrder::TOP)
          Gosu.draw_rect(x + @album_size - outline_thickness, y, outline_thickness, @album_size, Gosu::Color::RED, ZOrder::TOP)
        end
      else
        #draw empty placeholder if needed
        Gosu.draw_rect(x, y, @album_size, @album_size, Gosu::Color.new(30, 30, 30), ZOrder::MIDDLE)
      end
    end
  end
 #draw the tracks of the selected ablum/playlist
  def draw_tracks
    return unless @selected_album_index

    album = @albums[@selected_album_index]

    #for the playlist album, show tracks with genre & year
    if album.title == "Playlist"
      tracks_to_show = @playlist
      x_start = 500
      y_start = 20
      @font.draw_text("Tracks from #{album.title}", x_start, y_start, ZOrder::TOP, 1.2, 1.2, Gosu::Color::WHITE)

      #display headers
      @small_font.draw_text("Track Name", x_start, y_start + 30, ZOrder::TOP, 1, 1, Gosu::Color::RED)
      @small_font.draw_text("Genre", x_start + 400, y_start + 30, ZOrder::TOP, 1, 1, Gosu::Color::RED)
      @small_font.draw_text("Year", x_start + 550, y_start + 30, ZOrder::TOP, 1, 1, Gosu::Color::RED)

      tracks_to_show.each_with_index do |track, i|
        y = y_start + 60 + i * 30
        album_of_track = @albums.find { |a| a.tracks.include?(track) }
        genre = album_of_track ? album_of_track.genre : "Unknown"
        year = album_of_track ? album_of_track.year : "Unknown"
        color = track.name == @now_playing ? Gosu::Color::RED : Gosu::Color::WHITE

        @small_font.draw_text(track.name, x_start, y, ZOrder::TOP, 1, 1, color)
        @small_font.draw_text(genre, x_start + 400, y, ZOrder::TOP, 1, 1, color)
        @small_font.draw_text(year, x_start + 550, y, ZOrder::TOP, 1, 1, color)
      end
    else
      #normal album display
      tracks_to_show = album.tracks
      x_start = 500
      y_start = 20
      @font.draw_text("Tracks from #{album.title}, by #{album.artist}", x_start, y_start, ZOrder::TOP, 1.2, 1.2, Gosu::Color::WHITE)

      tracks_to_show.each_with_index do |track, i|
        y = y_start + 40 + i * 30
        color = track.name == @now_playing ? Gosu::Color::RED : Gosu::Color::WHITE
        @small_font.draw_text("#{i + 1}. #{track.name}", x_start, y, ZOrder::TOP, 1, 1, color)
      end
    end
  end

  #draw currently playing track and control buttons
  def draw_now_playing
    message = @now_playing.empty? ? "No tracks selected" : "Now Playing: #{@now_playing}"
    @font.draw_text(message,  500, @win_height - 100, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)

    #pause/Play button
    color = @stop_button_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    text_color = @stop_button_hover ? Gosu::Color::WHITE : Gosu::Color::BLACK
    label = @is_paused ? "Play" : "Pause"

    Gosu.draw_rect(@stop_button_x, @stop_button_y, @stop_button_width, @stop_button_height, color, ZOrder::MIDDLE)
    @font.draw_text(label, @stop_button_x + 30, @stop_button_y + 8, ZOrder::TOP, 1, 1, text_color)

    prev_color = @prev_track_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    prev_text_color = @prev_track_hover ? Gosu::Color::WHITE : Gosu::Color::BLACK
    Gosu.draw_rect(@prev_track_x, @track_button_y, @track_button_width, @track_button_height, prev_color, ZOrder::MIDDLE)
    @font.draw_text("Previous", @prev_track_x + 15, @track_button_y + 10, ZOrder::TOP, 1, 1, prev_text_color)

    #next Track Button
    next_color = @next_track_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    next_text_color = @next_track_hover ? Gosu::Color::WHITE : Gosu::Color::BLACK
    Gosu.draw_rect(@next_track_x, @track_button_y, @track_button_width, @track_button_height, next_color, ZOrder::MIDDLE)
    @font.draw_text("Next", @next_track_x + 15, @track_button_y + 10, ZOrder::TOP, 1, 1, next_text_color)
    
    #draw playlist, history, or queue if visible
    if @show_playlist
      #playlist title
      @font.draw_text("Playlist", 500, 268, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)

      #playlist tracks
      @playlist.each_with_index do |track, i|
        @small_font.draw_text("#{i + 1}. #{track.name}", 500, 305 + i * 30, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)
      end
    end

    if @show_history
      @font.draw_text("History (last 6)", 1000, 268, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)
      last_6_tracks = @track_history.last(6).reverse  # most recent first

      last_6_tracks.each_with_index do |track, i|
        y = 305 + i * 30
        #highlight if currently playing
        color = track.name == @now_playing ? Gosu::Color::RED : Gosu::Color::WHITE
        @small_font.draw_text("#{i + 1}. #{track.name}", 1000, y, ZOrder::TOP, 1, 1, color)
      end
    end

    if @show_queue
      @font.draw_text("Queue", 500, 268, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)
      @queue.each_with_index do |track, i|
        @small_font.draw_text("#{i + 1}. #{track.name}", 500, 305 + i * 30, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)
      end
    end

  end
  #draw buttons for pagination, playlist, queue, history
  def draw_page_buttons
    button_y = @button_y
    prev_x = @win_width - 960
    next_x = @win_width - 850
    width = 100
    height = 35

    #previous button
    prev_color = @prev_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    Gosu.draw_rect(prev_x, button_y, width, height, prev_color, ZOrder::MIDDLE)
    @font.draw_text("<-----", prev_x + 15, button_y + 8, ZOrder::TOP, 1, 1, Gosu::Color::BLACK)

    #next button
    next_color = @next_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    Gosu.draw_rect(next_x, button_y, width, height, next_color, ZOrder::MIDDLE)
    @font.draw_text("----->", next_x + 20, button_y + 8, ZOrder::TOP, 1, 1, Gosu::Color::BLACK)

    #playlist button 
    playlist_x = @playlist_button_x
    playlist_y = @playlist_button_y
    playlist_width = @playlist_button_width
    playlist_height = @playlist_button_height

    playlist_color = @playlist_button_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    Gosu.draw_rect(playlist_x, playlist_y, playlist_width, playlist_height, playlist_color, ZOrder::MIDDLE)
    @font.draw_text("Playlist", playlist_x + 10, playlist_y + 8, ZOrder::TOP, 1, 1, Gosu::Color::BLACK)

    #queue button
    queue_color = @queue_button_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    Gosu.draw_rect(@queue_button_x, @queue_button_y, @queue_button_width, @queue_button_height, queue_color, ZOrder::MIDDLE)
    @font.draw_text("Queue", @queue_button_x + 25, @queue_button_y + 8, ZOrder::TOP, 1, 1, Gosu::Color::BLACK)

    #page info
    @small_font.draw_text("Page #{@current_page + 1} / #{@total_pages}", @win_width - 900, @win_height - 100, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)

    #history button
    history_color = @history_button_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    Gosu.draw_rect(@history_button_x, @history_button_y, @history_button_width, @history_button_height, history_color, ZOrder::MIDDLE)
    @font.draw_text("History", @history_button_x + 15, @history_button_y + 8, ZOrder::TOP, 1, 1, Gosu::Color::BLACK)
  end
  #always show cursor
  def needs_cursor?; true; end

  #update method called every frame
  def update
    start_index = @current_page * @albums_per_page
    visible_albums = @albums[start_index, @albums_per_page] || []

    #reset all hover states once
    @album_hover.map!.with_index { |_, i| false }

    #update hover states for visible albums
    visible_albums.each_with_index do |_, idx|
      col = idx % 2
      row = idx / 2
      x = 20 + col * @album_spacing_x
      y = 20 + row * @album_spacing_y
      global_index = start_index + idx

      @album_hover[global_index] = mouse_x.between?(x, x + @album_size) &&
        mouse_y.between?(y, y + @album_size)
    end

     #update hover states for all buttons
    @stop_button_hover = mouse_x.between?(@stop_button_x, @stop_button_x + @stop_button_width) &&
      mouse_y.between?(@stop_button_y, @stop_button_y + @stop_button_height)

    @prev_track_hover = mouse_x.between?(@prev_track_x, @prev_track_x + @track_button_width) &&
      mouse_y.between?(@track_button_y, @track_button_y + @track_button_height)

    @next_track_hover = mouse_x.between?(@next_track_x, @next_track_x + @track_button_width) &&
      mouse_y.between?(@track_button_y, @track_button_y + @track_button_height)

    @prev_hover = mouse_x.between?(@win_width - 960, @win_width - 860) &&
      mouse_y.between?(@button_y, @button_y + 35)

    @next_hover = mouse_x.between?(@win_width - 850, @win_width - 750) &&
      mouse_y.between?(@button_y, @button_y + 35)

    @playlist_button_hover = mouse_x.between?(@playlist_button_x, @playlist_button_x + @playlist_button_width) &&
      mouse_y.between?(@playlist_button_y, @playlist_button_y + @playlist_button_height)

    @queue_button_hover = mouse_x.between?(@queue_button_x, @queue_button_x + @queue_button_width) &&
      mouse_y.between?(@queue_button_y, @queue_button_y + @queue_button_height)
    
    @history_button_hover = mouse_x.between?(@history_button_x, @history_button_x + @history_button_width) &&
      mouse_y.between?(@history_button_y, @history_button_y + @history_button_height)

    #automatically play next track from queue if current song finished         
    if @current_song && !@current_song.playing? && !@is_paused
      if !@queue.empty?
        play_next_from_queue
      end
    end
  end

  #helper method to handle playing a track and updating history
  def on_track_click(track)
    @now_playing = track.name
    play_track(track)

  #add the track to the history again (duplicate allowed)
    @track_history << track

  #update the history index to point to this most recent occurrence
    @track_history_index = @track_history.length - 1
  end

  #play from queue
  def play_next_from_queue
    return if @queue.empty?
    next_track = @queue.shift
    on_track_click(next_track)
  end

  #handle mouse clicks on buttons, albums, and tracks
  def button_down(id)
    return unless id == Gosu::MsLeft #only left click

    #previous track from history
    if @prev_track_hover && @track_history_index && @track_history_index > 0
      @track_history_index -= 1
      track = @track_history[@track_history_index]
      @now_playing = track.name
      play_track(track)
      return
    end

    #next track
    if @next_track_hover && @track_history_index
      if @track_history_index < @track_history.length - 1
        #go to next track in history
        @track_history_index += 1
        track = @track_history[@track_history_index]
        @now_playing = track.name
        play_track(track)
        return
      elsif !@queue.empty?
        #no more tracks in history, play from queue instead
        next_track = @queue.shift       #take first track in queue
        @now_playing = next_track.name
        play_track(next_track)
        puts "Now playing from queue: #{next_track.name}"
        return
      end
    end

    #stop/play button
    if @stop_button_hover
      if @current_song
        if @is_paused
          @current_song.play(false)
          @is_paused = false
        else
          @current_song.pause
          @is_paused = true
        end
      end
      return
    end

    #page buttons
    if @prev_hover && @current_page > 0
      @current_page -= 1
      return
    elsif @next_hover && @current_page < @total_pages - 1
      @current_page += 1
    return
    end

    #playlist button
    if @playlist_button_hover
      @show_playlist = !@show_playlist
      @show_queue = false if @show_playlist   #hide queue if playlist is shown
      return
    end

    #queue button
    if @queue_button_hover
      @show_queue = !@show_queue
      @show_playlist = false if @show_queue   #hide playlist if queue is shown
      return
    end

    #album click
    start_index = @current_page * @albums_per_page
    visible_albums = @albums[start_index, @albums_per_page] || []

    visible_albums.each_with_index do |_, idx|
      col = idx % 2
      row = idx / 2
      x = 20 + col * @album_spacing_x
      y = 20 + row * @album_spacing_y
      global_index = start_index + idx

      if mouse_x.between?(x, x + @album_size) && mouse_y.between?(y, y + @album_size)
        @selected_album_index = global_index
        return
      end
    end

    #history button
    if @history_button_hover
      @show_history = !@show_history
      @show_playlist = false
      @show_queue = false
      return
    end

    #display track history 
    if @show_history
      history_x = 1000
      history_y = 305
      track_height = 30
      last_6_tracks = @track_history.last(6).reverse #only last 6 

      last_6_tracks.each_with_index do |track, i|
        y = history_y + i * track_height
        if mouse_x.between?(history_x, history_x + 300) && mouse_y.between?(y, y + track_height)
          on_track_click(track)  #play the clicked track
          return
        end
      end
    end

    #playlist display and sorting
    if @selected_album_index && @albums[@selected_album_index].title == "Playlist" && id == Gosu::MsLeft
      x_start = 500
      y_header = 50  
      if mouse_y.between?(y_header, y_header + 20)
    #only sort by genre
        if mouse_x.between?(x_start + 400, x_start + 520)
          @playlist.sort_by! do |t|
            album_of_track = @albums.find { |a| a.tracks.include?(t) }
            album_of_track ? album_of_track.genre : ""
          end
          return
    #only sort by year
        elsif mouse_x.between?(x_start + 550, x_start + 630)
          @playlist.sort_by! do |t|
            album_of_track = @albums.find { |a| a.tracks.include?(t) }
            album_of_track ? album_of_track.year.to_i : 0
          end
          return
        end
      end
    end

    #queue display 
    if @show_queue
      queue_x = 500
      queue_y = 330
      track_height = 25
      clicked_index = nil

      @queue.each_with_index do |track, i|
        y = queue_y + i * track_height
        if mouse_x.between?(queue_x, queue_x + 300) && mouse_y.between?(y, y + track_height)
          on_track_click(track)
          clicked_index = i
          break
        end
      end

      if clicked_index
        track = @queue.delete_at(clicked_index)
        @track_history << track
        @track_history_index = @track_history.length - 1
      end
    end
  
  #track click (only if an album is selected)
    if @selected_album_index
      album = @albums[@selected_album_index]
      x_start = 500
      y_start = 60

      tracks_to_show = (album.title == "Playlist") ? @playlist : album.tracks

      tracks_to_show.each_with_index do |track, i|
        y = y_start + i * 30
        if mouse_x.between?(x_start, x_start + 300) && mouse_y.between?(y, y + 20)
          if @show_playlist
            #playlist mode: add track from album to playlist
            @playlist << track unless @playlist.include?(track) || @playlist.size >= 6
          elsif @show_queue
            #queue mode: add track to queue
            @queue << track unless @queue.include?(track)
          else
            #normal mode: play track immediately
            on_track_click(track)
          end
          return
        end
      end
    end
  
    #remove from playlist
    if @show_playlist
      playlist_x = 500
      playlist_y = 305
      track_height = 30
      @playlist.each_with_index do |track, i|
        y = playlist_y + i * track_height
        if mouse_x.between?(playlist_x, playlist_x + 300) && mouse_y.between?(y, y + track_height)
          @playlist.delete(track)
          return
        end
      end
    end
  end

  #play the track with Gosu::Song
  def play_track(track)
    @is_paused = false
    @current_song&.stop
    puts "Trying to play: #{track.file}"
    unless File.exist?(track.file)
      puts "ERROR: file not found!"
      return
    end
    @current_song = Gosu::Song.new(track.file)
    @current_song.play(false)
  end

  #completely stop the music
  def stop_music
    if @current_song
      @current_song.stop
      @now_playing = ""
    end
  end
end

#read albums from file and launch player
albums = read_albums("albums.txt")
MusicPlayer.new(albums).show