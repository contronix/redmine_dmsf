# frozen_string_literal: true

# Redmine plugin for Document Management System "Features"
#
# Vít Jonáš <vit.jonas@gmail.com>, Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'zip'

module RedmineDmsf
  module DmsfZip
    # ZIP
    class Zip
      attr_reader :files

      def initialize
        @temp_file = Tempfile.new(%w[dmsf_zip_ .zip], Rails.root.join('tmp'))
        @zip_file = ::Zip::OutputStream.open(@temp_file)
        @files = []
        @folders = []
      end

      def finish
        @zip_file.close
        @temp_file.path
      end

      def close
        @zip_file.close
      end

      def add_file(file, member, root_path = nil)
        return if @files.include?(file)
        unless file&.last_revision && File.exist?(file.last_revision&.disk_file)
          raise RedmineDmsf::Errors::DmsfFileNotFoundError
        end

        string_path = file.dmsf_folder.nil? ? '' : (file.dmsf_folder.dmsf_path_str + File::SEPARATOR)
        string_path = string_path[(root_path.length + 1)..string_path.length] if root_path
        string_path += file.formatted_name(member)
        zip_entry = ::Zip::Entry.new(@zip_file, string_path, nil, nil, nil, nil, nil, nil,
                                     ::Zip::DOSTime.at(file.last_revision.updated_at))
        @zip_file.put_next_entry(zip_entry)
        File.open(file.last_revision.disk_file, 'rb') do |f|
          while (buffer = f.read(8192))
            @zip_file.write(buffer)
          end
        end
        @files << file
      end

      def add_folder(folder, member, root_path = nil)
        return if @folders.include?(folder)

        string_path = folder.dmsf_path_str + File::SEPARATOR
        string_path = string_path[(root_path.length + 1)..string_path.length] if root_path
        zip_entry = ::Zip::Entry.new(@zip_file, string_path, nil, nil, nil, nil, nil, nil,
                                     ::Zip::DOSTime.at(folder.modified))
        @zip_file.put_next_entry(zip_entry)
        @folders << folder
        folder.dmsf_folders.visible.each { |subfolder| add_folder(subfolder, member, root_path) }
        folder.dmsf_files.visible.each { |file| add_file(file, member, root_path) }
      end
    end
  end
end
