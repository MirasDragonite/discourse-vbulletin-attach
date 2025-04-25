# frozen_string_literal: true
# name: discourse-vbulletin-attach
# about: Converts vBulletin [ATTACH=JSON] tags to proper image tags
# version: 0.4
# authors: CPA Club Team
# url: https://github.com/MirasDragonite/discourse-vbulletin-attach

after_initialize do
  require 'json'

  module ::VBulletinAttachConverter
    def self.convert_attachments(text)
      # Обрабатываем [ATTACH=JSON] теги
      text = convert_attach_json(text)

      # Обрабатываем [IMG2=JSON] теги
      text = convert_img2_json(text)

      return text
    end

    # Метод для обработки [ATTACH=JSON] тегов
    def self.convert_attach_json(text)
      return text unless text.is_a?(String) && text.include?("[ATTACH=JSON]")

      text.gsub(/\[ATTACH=JSON\](.*?)\[\/ATTACH\]/m) do
        raw_json = $1
        raw_json.gsub!(/[“”]/, '"')

        begin
          json = JSON.parse(raw_json)

          alt = json["alt"] || ""
          title = json["title"] || ""

          filename = nil

          if title.present?
            filename = title.strip
          end

          if !filename && alt.present?
            name_match = alt.match(/Название:\s*([^\.]+\.[^\s]+)/u) || 
                         alt.match(/Название:\s*([^\s]+)/u)
            filename = name_match[1] if name_match
          end

          filename ||= "unknown.png"

          upload = Upload.find_by(original_filename: filename)

          if upload
            width = json["width"] || upload.width
            height = json["height"] || upload.height
            src = upload.url

            align_class = ""
            if json["data-align"] && json["data-align"] != "none"
              align_class = " class=\"align-#{json["data-align"]}\""
            end

            img_tag = %Q{<img src="#{src}" alt="#{CGI.escapeHTML(filename)}" width="#{width}" height="#{height}"#{align_class}>}
            img_tag
          else
            message = "[ATTACH: #{filename} (ID: #{json["data-attachmentid"] || 'unknown'}) not found]"
            message
          end
        rescue => e
          "[ATTACH parse error: #{e.message.gsub(/[<>]/, '')}]"
        end
      end
    end

    # Метод для обработки [IMG2=JSON] тегов
    def self.convert_img2_json(text)
      return text unless text.is_a?(String) && text.include?("[IMG2=JSON]")

      text.gsub(/\[IMG2=JSON\](.*?)\[\/IMG2\]/m) do
        raw_json = $1
        raw_json.gsub!(/[“”]/, '"')

        begin
          json = JSON.parse(raw_json)

          src = json["src"] || ""
          align_class = json["data-align"] && json["data-align"] != "none" ? " class=\"align-#{json["data-align"]}\"" : ""
          size_class = json["data-size"] == "full" ? " class=\"full-size\"" : ""

          img_tag = %Q{<img src="#{src}"#{align_class}#{size_class}>}
          img_tag
        rescue => e
          "[IMG2 parse error: #{e.message.gsub(/[<>]/, '')}]"
        end
      end
    end
  end

  # Обработка при создании поста
  on(:before_post_create) do |post, params|
    if params[:raw]&.include?("[ATTACH=JSON]") || params[:raw]&.include?("[IMG2=JSON]")
      begin
        params[:raw] = ::VBulletinAttachConverter.convert_attachments(params[:raw])
      rescue => e
        Rails.logger.error("VBulletinAttachConverter before_post_create error: #{e.message}")
      end
    end
  end
  
  # Обработка при редактировании
  on(:before_post_update) do |post, params|
    if params[:raw]&.include?("[ATTACH=JSON]") || params[:raw]&.include?("[IMG2=JSON]")
      begin
        params[:raw] = ::VBulletinAttachConverter.convert_attachments(params[:raw])
      rescue => e
        Rails.logger.error("VBulletinAttachConverter before_post_update error: #{e.message}")
      end
    end
  end

  # При отображении существующего поста
  on(:post_process_cooked) do |doc, post|
    if post.raw&.include?("[ATTACH=JSON]") || post.raw&.include?("[IMG2=JSON]")
      begin
        new_raw = ::VBulletinAttachConverter.convert_attachments(post.raw)
        if new_raw != post.raw
          post.update_column(:raw, new_raw)
          post.rebake!
        end
      rescue => e
        Rails.logger.error("VBulletinAttachConverter post_process_cooked error: #{e.message}")
      end
    end
  end

  # Для рендеринга
  plugin = self
  reloadable_patch do
    module ::PrettyText
      class << self
        alias_method :original_cook_without_vbulletin_attach, :cook unless method_defined?(:original_cook_without_vbulletin_attach)
        
        def cook(text, opts = {})
          if text.is_a?(String) && (text.include?("[ATTACH=JSON]") || text.include?("[IMG2=JSON]"))
            begin
              text = ::VBulletinAttachConverter.convert_attachments(text)
            rescue => e
              Rails.logger.error("VBulletinAttachConverter cook error: #{e.message}")
            end
          end
          original_cook_without_vbulletin_attach(text, opts)
        end
      end
    end
  end
end
