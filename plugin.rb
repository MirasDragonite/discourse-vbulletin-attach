# frozen_string_literal: true
# name: discourse-vbulletin-attach
# about: Converts vBulletin [ATTACH=JSON], [IMG2=JSON], [SIZE], [RIGHT], [I] tags to proper HTML
# version: 0.5
# authors: CPA Club Team
# url: https://github.com/MirasDragonite/discourse-vbulletin-attach

after_initialize do
  require 'json'

  module ::VBulletinAttachConverter
    def self.convert_attachments(text)
      return text unless text.is_a?(String)

      # Обрабатываем [ATTACH=JSON] теги
      text = convert_attach_json(text)

      # Обрабатываем [IMG2=JSON] теги
      text = convert_img2_json(text)

      # Обрабатываем [RIGHT] теги
      text = convert_right_tags(text)

      # Обрабатываем [I] теги
      text = convert_i_tags(text)

      # Обрабатываем [SIZE] теги
      text = convert_size_tags(text)

      text
    end

    def self.convert_attach_json(text)
      return text unless text.include?("[ATTACH=JSON]")

      text.gsub(/\[ATTACH=JSON\](.*?)\[\/ATTACH\]/m) do
        raw_json = $1
        raw_json.gsub!(/[“”]/, '"')

        begin
          json = JSON.parse(raw_json)

          alt = json["alt"] || ""
          title = json["title"] || ""

          filename = title.presence || alt[/Название:\s*([^\.]+\.[^\s]+)/u, 1] || alt[/Название:\s*([^\s]+)/u, 1] || "unknown.png"

          upload = Upload.find_by(original_filename: filename)

          if upload
            width = json["width"] || upload.width
            height = json["height"] || upload.height
            src = upload.url

            align_class = json["data-align"].present? && json["data-align"] != "none" ? " class=\"align-#{json["data-align"]}\"" : ""

            %Q{<img src="#{src}" alt="#{CGI.escapeHTML(filename)}" width="#{width}" height="#{height}"#{align_class}>}
          else
            "[ATTACH: #{filename} (ID: #{json["data-attachmentid"] || 'unknown'}) not found]"
          end
        rescue => e
          "[ATTACH parse error: #{e.message.gsub(/[<>]/, '')}]"
        end
      end
    end

    def self.convert_img2_json(text)
      return text unless text.include?("[IMG2=JSON]")
    
      text.gsub(/\[IMG2=JSON\](.*?)\[\/IMG2\]/m) do
        raw_json = $1
        raw_json.gsub!(/[“”]/, '"')
    
        begin
          json = JSON.parse(raw_json)
    
          src = json["src"] || ""
          align_class = json["data-align"].present? && json["data-align"] != "none" ? " class=\"align-#{json["data-align"]}\"" : ""
          size_class = json["data-size"] == "full" ? " class=\"full-size\"" : ""
    
          # Проверка, является ли src Base64 изображением
          if src.include?("base64,")
            # Если это Base64, то не меняем src, просто вставляем его в правильном формате
            if src.match(/^https?:\/\/[^\s]+;base64,/)
              # Если в URL содержится base64, разделяем его и добавляем префикс для Base64
              base64_data = src.split('base64,').last
              # Добавляем префикс для Base64-данных, автоматически определяя формат изображения
              src = "data:image/#{src.split(';').first.split('/').last};base64,#{base64_data}"
            end
          
            # Вставляем изображение с Base64
            %Q{<img src="#{src}"#{align_class}#{size_class}>}
          else
            # Если это обычный URL, обработка как обычно
            %Q{<img src="#{src}"#{align_class}#{size_class}>}
          end          
        rescue => e
          "[IMG2 parse error: #{e.message.gsub(/[<>]/, '')}]"
        end
      end
    end
    

    def self.convert_size_tags(text)
      return text unless text.include?("[SIZE=")

      # Обработка [SIZE=20px]Текст[/SIZE]
      text.gsub(/\[SIZE=(\d+)(?:px)?\](.*?)\[\/SIZE\]/mi) do
        size = $1
        content = $2
        %Q{<span style="font-size:#{size}px">#{content}</span>}
      end
    end    

    def self.convert_right_tags(text)
      return text unless text.include?("[RIGHT]")

      text.gsub(/\[RIGHT\](.*?)\[\/RIGHT\]/mi) do
        content = $1.strip
        %Q{<div style="text-align:right">#{content}</div>}
      end
    end

    def self.convert_i_tags(text)
      return text unless text.include?("[I]")

      text.gsub(/\[I\](.*?)\[\/I\]/mi) do
        content = $1
        %Q{<i>#{content}</i>}
      end
    end
  end

  # Обработка при создании поста
  on(:before_post_create) do |post, params|
    if params[:raw]
      begin
        params[:raw] = ::VBulletinAttachConverter.convert_attachments(params[:raw])
      rescue => e
        Rails.logger.error("VBulletinAttachConverter before_post_create error: #{e.message}")
      end
    end
  end

  # Обработка при редактировании
  on(:before_post_update) do |post, params|
    if params[:raw]
      begin
        params[:raw] = ::VBulletinAttachConverter.convert_attachments(params[:raw])
      rescue => e
        Rails.logger.error("VBulletinAttachConverter before_post_update error: #{e.message}")
      end
    end
  end

  # При отображении существующего поста
  on(:post_process_cooked) do |doc, post|
    if post.raw
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
  reloadable_patch do
    module ::PrettyText
      class << self
        alias_method :original_cook_without_vbulletin_attach, :cook unless method_defined?(:original_cook_without_vbulletin_attach)

        def cook(text, opts = {})
          if text.is_a?(String)
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
