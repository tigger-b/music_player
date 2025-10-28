require 'gosu'

# Small test window
class SoundTest < Gosu::Window
  def initialize
    super(200, 200, false)
    self.caption = "Gosu Sound Test"

    # Path to your sound file
    file_path = "/Users/tadhgbryant/Desktop/music_player/media/boing_x.wav"

    if File.exist?(file_path)
      puts "Found file at: #{file_path}"
      @song = Gosu::Song.new(file_path)
    else
      puts "File not found!"
      exit
    end
  end

  def button_down(id)
    if id == Gosu::KB_SPACE
      puts "Playing sound..."
      @song.play(false)
    elsif id == Gosu::KB_ESCAPE
      close
    end
  end

  def draw
    Gosu.draw_rect(0, 0, 200, 200, Gosu::Color::AQUA, 0)
    Gosu::Font.new(20).draw_text("Press SPACE to play", 10, 90, 1, 1, 1, Gosu::Color::BLACK)
  end
end

SoundTest.new.show
