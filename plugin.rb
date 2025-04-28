# name: discourse-vbulletin-attach
# about: Заменяет [ATTACH=JSON] на <img> при сохранении и рендере
# version: 0.1

after_initialize do
  require 'json'

  module ::VBulletinAttachConverter
    def self.convert_attachments(text)
      return text unless text&.include?("[ATTACH=JSON]")

      text.gsub(/\[ATTACH=JSON\](.*?)\[\/ATTACH\]/m) do
        raw_json = $1
        begin
          json = JSON.parse(raw_json)

          alt = json["alt"] || ""
          filename = alt[/Название:\s*(.+?)\s/u, 1] || "unknown.png"

          upload = Upload.find_by(original_filename: filename)

          if upload
            width = json["width"] || upload.width
            height = json["height"] || upload.height
            src = upload.url

            %Q{<img src="#{src}" alt="#{filename}" width="#{width}" height="#{height}">}
          else
            "<!-- Attachment '#{filename}' not found -->"
          end
        rescue => e
          "<!-- ATTACH parse error: #{e.message} -->"
        end
      end
    end
  end

  # 🔁 При сохранении поста — заменяем в raw
  class ::Post
    before_save do
      if self.raw&.include?("[ATTACH=JSON]")
        self.raw = ::VBulletinAttachConverter.convert_attachments(self.raw)
      end
    end
  end

  # 🧾 При рендере поста (на всякий случай)
  module ::PrettyText
    class << self
      alias_method :original_cook, :cook

      def cook(text, opts = {})
        result = original_cook(text, opts)
        ::VBulletinAttachConverter.convert_attachments(result)
      end
    end
  end
end