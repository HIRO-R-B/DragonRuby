# Copyright (c) 2012 Sam Stephenson

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module Dimensions
  class Scanner
    class ScanError < ::StandardError; end

    attr_reader :pos

    def initialize(data)
      @data = data.dup
      @data.force_encoding("BINARY") if @data.respond_to?(:force_encoding)
      @size = @data.length
      @pos  = 0
      big!  # endianness
    end

    def read_char
      read(1, "C")
    end

    def read_short
      read(2, @big ? "n" : "v")
    end

    def read_long
      read(4, @big ? "N" : "V")
    end

    def read(size, format)
      data = read_data(size)
      data.unpack(format)[0]
    end

    def read_data(size)
      data = @data[@pos, size]
      advance(size)
      data
    end

    def advance(length)
      @pos += length
      raise_scan_error if @pos > @size
    end

    def skip_to(pos)
      @pos = pos
      raise_scan_error if @pos > @size
    end

    def big!
      @big = true
    end

    def little!
      @big = false
    end

    def raise_scan_error
      raise ScanError
    end
  end
end

module Dimensions
  module TiffScanning
    def scan_header
      scan_endianness
      scan_tag_mark
      scan_and_skip_to_offset
    end

    def scan_endianness
      tag = [read_char, read_char]
      tag == [0x4D, 0x4D] ? big! : little!
    end

    def scan_tag_mark
      raise_scan_error unless read_short == 0x002A
    end

    def scan_and_skip_to_offset
      offset = read_long
      skip_to(offset)
    end

    def scan_ifd
      offset = pos
      entry_count = read_short

      entry_count.times do |i|
        skip_to(offset + 2 + (12 * i))
        tag = read_short
        yield tag
      end
    end

    def read_integer_value
      type = read_short
      advance(4)

      if type == 3
        read_short
      elsif type == 4
        read_long
      else
        raise_scan_error
      end
    end
  end
end

module Dimensions
  class JpegScanner < Scanner
    SOF_MARKERS = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF]
    EOI_MARKER  = 0xD9  # end of image
    SOS_MARKER  = 0xDA  # start of stream
    APP1_MARKER = 0xE1  # maybe EXIF

    attr_reader :width, :height, :angle

    def initialize(data)
      @width  = nil
      @height = nil
      @angle  = 0
      super
    end

    def scan
      advance(2)

      while marker = read_next_marker
        case marker
        when *SOF_MARKERS
          scan_start_of_frame
        when EOI_MARKER, SOS_MARKER
          break
        when APP1_MARKER
          scan_app1_frame
        else
          skip_frame
        end
      end

      width && height
    end

    def read_next_marker
      c = read_char while c != 0xFF
      c = read_char while c == 0xFF
      c
    end

    def scan_start_of_frame
      length = read_short
      read_char # depth, unused
      height = read_short
      width  = read_short
      size   = read_char

      if length == (size * 3) + 8
        @width, @height = width, height
      else
        raise_scan_error
      end
    end

    def scan_app1_frame
      frame = read_frame
      if frame[0..5] == "Exif\000\000"
        scanner = ExifScanner.new(frame[6..-1])
        if scanner.scan
          case scanner.orientation
          when :bottom_right
            @angle = 180
          when :left_top, :right_top
            @angle = 90
          when :right_bottom, :left_bottom
            @angle = 270
          end
        end
      end
    rescue ExifScanner::ScanError
    end

    def read_frame
      length = read_short - 2
      read_data(length)
    end

    def skip_frame
      length = read_short - 2
      advance(length)
    end
  end
end

module Dimensions
  class Reader
    GIF_HEADER    = [0x47, 0x49, 0x46, 0x38]
    PNG_HEADER    = [0x89, 0x50, 0x4E, 0x47]
    JPEG_HEADER   = [0xFF, 0xD8, 0xFF]
    TIFF_HEADER_I = [0x49, 0x49, 0x2A, 0x00]
    TIFF_HEADER_M = [0x4D, 0x4D, 0x00, 0x2A]

    attr_reader :type, :width, :height, :angle

    def initialize
      @process = :determine_type
      @type    = nil
      @width   = nil
      @height  = nil
      @angle   = nil
      @size    = 0
      @data    = ""
      @data.force_encoding("BINARY") if @data.respond_to?(:force_encoding)
    end

    def <<(data)
      if @process
        @data << data
        @size = @data.length
        process
      end
    end

    def process(process = @process)
      send(@process) if @process = process
    end

    def determine_type
      if @size >= 4
        bytes = @data.unpack("C4")

        if match_header(GIF_HEADER, bytes)
          @type = :gif
        elsif match_header(PNG_HEADER, bytes)
          @type = :png
        elsif match_header(JPEG_HEADER, bytes)
          @type = :jpeg
        elsif match_header(TIFF_HEADER_I, bytes) || match_header(TIFF_HEADER_M, bytes)
          @type = :tiff
        end

        process @type ? :"extract_#{type}_dimensions" : nil
      end
    end

    def extract_gif_dimensions
      if @size >= 10
        @width, @height = @data.unpack("x6v2")
        process nil
      end
    end

    def extract_png_dimensions
      if @size >= 24
        @width, @height = @data.unpack("x16N2")
        process nil
      end
    end

    def extract_jpeg_dimensions
      scanner = JpegScanner.new(@data)
      if scanner.scan
        @width  = scanner.width
        @height = scanner.height
        @angle  = scanner.angle

        if @angle == 90 || @angle == 270
          @width, @height = @height, @width
        end

        process nil
      end
    rescue JpegScanner::ScanError
    end

    def extract_tiff_dimensions
      scanner = TiffScanner.new(@data)
      if scanner.scan
        @width  = scanner.width
        @height = scanner.height
        process nil
      end
    rescue TiffScanner::ScanError
    end

    def match_header(header, bytes)
      bytes[0, header.length] == header
    end
  end
end

module Dimensions
  module IO
    def self.extended(io)
      io.instance_variable_set(:@reader, Reader.new)
    end

    def read(*args)
      super.tap do |data|
        @reader << data if data
      end
    end

    def dimensions
      [width, height] if width && height
    end

    def width
      peek
      @reader.width
    end

    def height
      peek
      @reader.height
    end

    def angle
      peek
      @reader.angle
    end

    private
      def peek
        unless no_peeking?
          read(pos + 1024) while @reader.width.nil? && pos < 6144
          rewind
        end
      end

      def no_peeking?
        @reader.width || closed? || pos != 0
      end
  end
end

module Dimensions
  class TiffScanner < Scanner
    include TiffScanning

    WIDTH_TAG  = 0x100
    HEIGHT_TAG = 0x101

    attr_reader :width, :height

    def initialize(data)
      @width  = nil
      @height = nil
      super
    end

    def scan
      scan_header

      scan_ifd do |tag|
        if tag == WIDTH_TAG
          @width = read_integer_value
        elsif tag == HEIGHT_TAG
          @height = read_integer_value
        end
      end

      @width && @height
    end
  end
end

module Dimensions
  VERSION = "1.3.0"
end

# Extends an IO object with the `Dimensions::IO` module, which adds
# `dimensions`, `width`, `height` and `angle` methods. The methods
# will return non-nil values once the IO has been sufficiently read,
# assuming its contents are an image.
def Dimensions(io)
  io.extend(Dimensions::IO)
end

module Dimensions
  class << self
    # Returns an array of [width, height] representing the dimensions
    # of the image at the given path.
    def dimensions(path)
      io_for(path).dimensions
    end

    # Returns the width of the image at the given path.
    def width(path)
      io_for(path).width
    end

    # Returns the height of the image at the given path.
    def height(path)
      io_for(path).height
    end

    # Returns the rotation angle of the JPEG image at the given
    # path. If the JPEG is rotated 90 or 270 degrees (as is often the
    # case with photos from smartphones, for example) its width and
    # height will be swapped to accurately reflect the rotation.
    def angle(path)
      io_for(path).angle
    end

    private
      def io_for(path)
        Dimensions(File.open(path, "rb")).tap do |io|
          io.read
          io.close
        end
      end
  end
end
