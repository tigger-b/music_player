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
    @win_width = 800
    @win_height = 600
    @album_size = 200
    @album_spacing_x = 250
    @album_spacing_y = 250

    super(@win_width, @win_height)
    self.caption = "🎵 Ruby GUI Music Player"

    
    @albums = albums
    @album_positions = []
    @album_hover = []
    @selected_album_index = nil
    @current_song = nil
    @now_playing = ""       #name of track currently playing

    
    @font = Gosu::Font.new(20)
    @small_font = Gosu::Font.new(16)

    @stop_button_hover = false
    @stop_button_x = 20
    @stop_button_y = @win_height - 60
    @stop_button_width = 120
    @stop_button_height = 35

    #images
    @artworks = albums.map do |a|
      path = File.join("media", a.artwork)
      if File.exist?(path)
        Gosu::Image.new(path)
      else
        #image not found case
        Gosu::Image.from_blob(@album_size, @album_size, "\xff\x00\x00\x00" * @album_size * @album_size)
      end
    end

    #grid for albums
    @albums.each_with_index do |_, i|
      col = i % 2
      row = i / 2
      x = 20 + col * @album_spacing_x
      y = 20 + row * @album_spacing_y
      @album_positions << [x, y]
      @album_hover << false
    end
  end

 
  def draw
    Gosu.draw_rect(0, 0, @win_width, @win_height, Gosu::Color.new(30, 30, 30), ZOrder::BACKGROUND)
    draw_albums
    draw_tracks
    draw_now_playing
  end

  def draw_albums
    @albums.each_with_index do |album, i|
      x, y = @album_positions[i]
      img = @artworks[i]

      
      scale_x = @album_size.to_f / img.width
      scale_y = @album_size.to_f / img.height
      img.draw(x, y, ZOrder::MIDDLE, scale_x, scale_y)

      
      if @album_hover[i]
        outline_thickness = 4
        # Top
        Gosu.draw_rect(x, y, @album_size, outline_thickness, Gosu::Color.argb(0xff_ff0000), ZOrder::TOP)
        # Bottom
        Gosu.draw_rect(x, y + @album_size - outline_thickness, @album_size, outline_thickness, Gosu::Color.argb(0xff_ff0000), ZOrder::TOP)
        # Left
        Gosu.draw_rect(x, y, outline_thickness, @album_size, Gosu::Color.argb(0xff_ff0000), ZOrder::TOP)
        # Right
        Gosu.draw_rect(x + @album_size - outline_thickness, y, outline_thickness, @album_size, Gosu::Color.argb(0xff_ff0000), ZOrder::TOP)
      end
    end
  end

  def draw_tracks
    return unless @selected_album_index
    album = @albums[@selected_album_index]
    x_start = 500
    y_start = 20

    @font.draw_text("Tracks from #{album.title}", x_start, y_start, ZOrder::TOP, 1.2, 1.2, Gosu::Color::WHITE)

    album.tracks.each_with_index do |track, i|
      y = y_start + 40 + i * 30
      color = if track.name == @now_playing
                Gosu::Color.argb(0xff_ff0000) #highight for track  
              else
                Gosu::Color::WHITE
              end
      @small_font.draw_text("#{i + 1}. #{track.name}", x_start, y, ZOrder::TOP, 1, 1, color)
    end
  end

  def draw_now_playing
    @font.draw_text("Now Playing: #{@now_playing}", 20, @win_height - 100, ZOrder::TOP, 1, 1, Gosu::Color::WHITE)
    #stop button
    color = @stop_button_hover ? Gosu::Color::RED : Gosu::Color::WHITE
    text_color = @stop_button_hover ? Gosu::Color::WHITE : Gosu::Color::BLACK

    Gosu.draw_rect(@stop_button_x, @stop_button_y, @stop_button_width, @stop_button_height, color, ZOrder::MIDDLE)
    @font.draw_text("⏹ Stop", @stop_button_x + 35, @stop_button_y + 8, ZOrder::TOP, 1, 1, text_color)
   
    
  end

  
  def needs_cursor?; true; end

  def update
    @album_positions.each_with_index do |(x, y), i|
      @album_hover[i] = mouse_x.between?(x, x + @album_size) && mouse_y.between?(y, y + @album_size)
    @stop_button_hover = mouse_x.between?(@stop_button_x, @stop_button_x + @stop_button_width) &&
      mouse_y.between?(@stop_button_y, @stop_button_y + @stop_button_height)
    end
  end

  def button_down(id)
    if id == Gosu::MsLeft
      #stop button click
      if @stop_button_hover
        stop_music
        return
      end
      #album click
      @album_positions.each_with_index do |(x, y), i|
        if mouse_x.between?(x, x + @album_size) && mouse_y.between?(y, y + @album_size)
          @selected_album_index = i
          return
        end
      end

      #track click
      return unless @selected_album_index
      album = @albums[@selected_album_index]
      x_start = 500
      y_start = 60
      album.tracks.each_with_index do |track, i|
        y = y_start + i * 30
        if mouse_x.between?(x_start, x_start + 300) && mouse_y.between?(y, y + 20)
          puts "Clicked #{track.file}"
          @now_playing = track.name     #for highlighted track
          play_track(track)
        end
      end
    end
  end

  def play_track(track)
    @current_song&.stop
    if File.exist?(track.file)
      puts "File exists: #{File.exist?(track.file)}"
      puts "Absolute path: #{File.expand_path(track.file)}"
      puts "Loading #{track.file}"
      @current_song = Gosu::Song.new(track.file)
      @current_song.play(false)
    end
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