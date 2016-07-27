class Message
  @@archive = []
  attr_accessor :author, :content
  def initialize(name,content)
    @author=name
    @content=content
    @@archive << self
  end

  def self.archive
    @@archive
  end

end
