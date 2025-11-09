require 'rubygems'
require 'gosu'

module ZOrder
  BACKGROUND, MIDDLE, TOP = *0..2
end

class Track
  attr_accessor :name, :file
  def initialize(name, file)
    @name = name.strip
    #@file = File.join("media", file.strip)
    @file = File.join(__dir__, "media", file.strip)
  end
end

class Album
  attr_accessor :title, :artist, :artwork, :tracks
  def initialize(title, artist, artwork, tracks)
    @title = title.strip
    @artist = artist.strip
    @artwork = artwork.strip
    @tracks = tracks
  end
end

def read_track(file); Track.new(file.gets.strip, file.gets.strip); end
def read_tracks(file)
  count = file.gets.to_i
  Array.new(count) { read_track(file) }
end

def read_album(file)
  Album.new(file.gets.strip, file.gets.strip, file.gets.strip, read_tracks(file))
end

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

    super(@win_width, @win_height)
    self.caption = "Ruby GUI Music Player"

    @button_y = @win_height - 60
    
    @albums = albums
    @album_positions = []
    @album_hover = Array.new(@albums.size, false)
    @selected_album_index = nil
    @current_song = nil
    @now_playing = ""       #name of track currently playing

    @albums_per_page = 4      #show 4 albums per page (2x2 grid)
    @current_page = 0
    @total_pages = (@albums.length.to_f / @albums_per_page).ceil
    
    @font = Gosu::Font.new(20)
    @small_font = Gosu::Font.new(16)

    @stop_button_hover = false
    @stop_button_x = 20
    @stop_button_y = @button_y
    @stop_button_width = 120
    @stop_button_height = 35

    @is_paused = false

    @track_button_width = 150
    @track_button_height = 35

    @prev_track_x = 160
    @next_track_x = 330
    @track_button_y = @button_y

    @prev_track_hover = false
    @next_track_hover = false


    #images
    @artworks = albums.map do |a|
      path = File.join(__dir__, "media", a.artwork)
      if File.exist?(path)
        Gosu::Image.new(path)
      else
        #image not found case
        Gosu::Image.from_blob(@album_size, @album_size, "\xff\x00\x00\x00" * @album_size * @album_size)
      end
    end

  end

  def draw
    Gosu.draw_rect(0, 0, @win_width, @win_height, Gosu::Color.new(30, 30, 30), ZOrder::BACKGROUND)
    draw_albums
    draw_tracks
    draw_now_playing
    draw_page_buttons  
  end

  def draw_albums
    start_index = @current_page * @albums_per_page
    0.upto(@albums_per_page - 1) do |idx|
      col = idx % 2
      row = idx / 2
      x = 20 + col * @album_spacing_x
      y = 20 + row * @album_spacing_y
      global_index = start_index + idx

      if global_index < @albums.size
        album = @albums[global_index]
        img = @artworks[global_index]
        scale_x = @album_size.to_f / img.width
        scale_y = @album_size.to_f / img.height
        img.draw(x, y, ZOrder::MIDDLE, scale_x, scale_y)

        if @album_hover[global_index]
          outline_thickness = 4
          Gosu.draw_rect(x, y, @album_size, outline_thickness, Gosu::Color::RED, ZOrder::TOP)
          Gosu.draw_rect(x, y + @album_size - outline_thickness, @album_size, outline_thickness, Gosu::Color::RED, ZOrder::TOP)
          Gosu.draw_rect(x, y, outline_thickness, @album_size, Gosu::Color::RED, ZOrder::TOP)
          Gosu.draw_rect(x + @album_size - outline_thickness, y, outline_thickness, @album_size, Gosu::Color::RED, ZOrder::TOP)
        end
      else
      # Draw empty placeholder if needed
        Gosu.draw_rect(x, y, @album_size, @album_size, Gosu::Color::GRAY, ZOrder::MIDDLE)
      end
    end
  end
  def draw_tracks
    return unless @selected_album_index

    album = @albums[@selected_album_index]
    x_start = 500
    y_start = 20

    @font.draw_text("Tracks from #{album.title}, by #{album.artist}", x_start, y_start, ZOrder::TOP, 1.2, 1.2, Gosu::Color::WHITE)

    album.tracks.each_with_index do |track, i|
      y = y_start + 40 + i * 30
      color = track.name == @now_playing ? Gosu::Color::RED : Gosu::Color::WHITE
      @small_font.draw_text("#{i + 1}. #{track.name}", x_start, y, ZOrder::TOP, 1, 1, color)
    end
  end

  def draw_now_playing
    message = @now_playing.empty? ? "No tracks selected" : "Now Playing: #{@now_playing}"
    @font.draw_text(message, 20, @win_height - 100, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)

  # Pause/Play button
    color = @stop_button_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    text_color = @stop_button_hover ? Gosu::Color::WHITE : Gosu::Color::BLACK
    label = @is_paused ? "▶ Play" : "⏸ Pause"

    Gosu.draw_rect(@stop_button_x, @stop_button_y, @stop_button_width, @stop_button_height, color, ZOrder::MIDDLE)
    @font.draw_text(label, @stop_button_x + 30, @stop_button_y + 8, ZOrder::TOP, 1, 1, text_color)

    prev_color = @prev_track_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    prev_text_color = @prev_track_hover ? Gosu::Color::WHITE : Gosu::Color::BLACK
    Gosu.draw_rect(@prev_track_x, @track_button_y, @track_button_width, @track_button_height, prev_color, ZOrder::MIDDLE)
    @font.draw_text("Previous Track", @prev_track_x + 15, @track_button_y + 10, ZOrder::TOP, 1, 1, prev_text_color)

# Next Track Button
    next_color = @next_track_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    next_text_color = @next_track_hover ? Gosu::Color::WHITE : Gosu::Color::BLACK
    Gosu.draw_rect(@next_track_x, @track_button_y, @track_button_width, @track_button_height, next_color, ZOrder::MIDDLE)
    @font.draw_text("Next Track", @next_track_x + 15, @track_button_y + 10, ZOrder::TOP, 1, 1, next_text_color)
    
  end

  def draw_page_buttons
    button_y = @button_y
    prev_x = @win_width - 240
    next_x = @win_width - 120
    width = 100
    height = 35

  #previous button
    prev_color = @prev_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    Gosu.draw_rect(prev_x, button_y, width, height, prev_color, ZOrder::MIDDLE)
    @font.draw_text("Prev", prev_x + 15, button_y + 8, ZOrder::TOP, 1, 1, Gosu::Color::BLACK)

  # next button
    next_color = @next_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    Gosu.draw_rect(next_x, button_y, width, height, next_color, ZOrder::MIDDLE)
    @font.draw_text("Next", next_x + 20, button_y + 8, ZOrder::TOP, 1, 1, Gosu::Color::BLACK)

  #page info
    @small_font.draw_text("Page #{@current_page + 1} / #{@total_pages}", @win_width - 360, button_y + 10, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)
  end
  
  def needs_cursor?; true; end

  def update
    start_index = @current_page * @albums_per_page
    visible_albums = @albums[start_index, @albums_per_page] || []

  #Reset all hover states once
    @album_hover.map!.with_index { |_, i| false }

  #Update hover states for visible albums
    visible_albums.each_with_index do |_, idx|
      col = idx % 2
      row = idx / 2
      x = 20 + col * @album_spacing_x
      y = 20 + row * @album_spacing_y
      global_index = start_index + idx

      @album_hover[global_index] = mouse_x.between?(x, x + @album_size) &&
        mouse_y.between?(y, y + @album_size)
    end

  # Stop button
    @stop_button_hover = mouse_x.between?(@stop_button_x, @stop_button_x + @stop_button_width) &&
      mouse_y.between?(@stop_button_y, @stop_button_y + @stop_button_height)

    @prev_track_hover = mouse_x.between?(@prev_track_x, @prev_track_x + @track_button_width) &&
      mouse_y.between?(@track_button_y, @track_button_y + @track_button_height)

    @next_track_hover = mouse_x.between?(@next_track_x, @next_track_x + @track_button_width) &&
      mouse_y.between?(@track_button_y, @track_button_y + @track_button_height)

    @prev_hover = mouse_x.between?(@win_width - 240, @win_width - 140) &&
              mouse_y.between?(@button_y, @button_y + 35)

    @next_hover = mouse_x.between?(@win_width - 120, @win_width - 20) &&
              mouse_y.between?(@button_y, @button_y + 35)
  end

  def button_down(id)
    return unless id == Gosu::MsLeft

  # Stop button
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

  # Page buttons
    if @prev_hover && @current_page > 0
      @current_page -= 1
      return
    elsif @next_hover && @current_page < @total_pages - 1
      @current_page += 1
      return
    end

  # Album click
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

    return unless @selected_album_index
    album = @albums[@selected_album_index]
    x_start = 500
    y_start = 60
    album.tracks.each_with_index do |track, i|
      y = y_start + i * 30
      if mouse_x.between?(x_start, x_start + 300) && mouse_y.between?(y, y + 20)
        @now_playing = track.name
        play_track(track)
        return
      end
    end

    if @prev_track_hover && @selected_album_index
      album = @albums[@selected_album_index]
      current_index = album.tracks.index { |t| t.name == @now_playing }
      if current_index && current_index > 0
        new_track = album.tracks[current_index - 1]
        @now_playing = new_track.name
        play_track(new_track)
      end
      return
    end

# Next Track
    if @next_track_hover && @selected_album_index
      album = @albums[@selected_album_index]
      current_index = album.tracks.index { |t| t.name == @now_playing }
      if current_index && current_index < album.tracks.length - 1
        new_track = album.tracks[current_index + 1]
        @now_playing = new_track.name
        play_track(new_track)
      end
      return
    end
  end

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
  def stop_music
    if @current_song
      @current_song.stop
      @now_playing = ""
    end
  end
end

albums = read_albums("albums.txt")
MusicPlayer.new(albums).show