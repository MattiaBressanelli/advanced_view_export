# This extension creates maps for edges, color, profiles, shadows ecc. and combines them into an image.

require 'sketchup.rb'

module MattiaBressanelli
  module AdvancedViewExport

    # global variables
    $output_folder = ""
    $export_name = ""
    $image_width = nil
    $image_height = nil
    $maps_array = []
    $composite
    $ambientocclusion_exist = false
    $boolean_exist = false
    
    # Main function
    def self.main()
       
        # display html UI
        dialog = UI::HtmlDialog.new(
            {
              :dialog_title => "Advanced view export",
              :scrollable => false,
              :resizable => false,
              :width => 360,
              :height => 680,
              :style => UI::HtmlDialog::STYLE_DIALOG
            }
        )
        dialog.set_file(File.join(File.dirname(__FILE__), "/dialogs/index.html"))
        dialog.center
        dialog.show

        dialog.add_action_callback("validate_width") { |action_context|
            UI.messagebox("Enter number between 1 and 9999")
        }

        dialog.add_action_callback("validate_height") { |action_context|
            UI.messagebox("Enter number between 1 and 9999")
        }

        # set output directory
        dialog.add_action_callback("set_output_dir") { |action_context|
            $output_folder = set_output_dir()
            if $output_folder === nil
                $output_folder = ""
            end
            js_command = "document.getElementById('output-folder').value = '" + $output_folder + "'"
            dialog.execute_script(js_command)
        }

        # get image name
        dialog.add_action_callback("get_image_name") { |action_context, image_name|
            $export_name = image_name.gsub(" ", "_").gsub(".", "_").gsub("/", "_").gsub("\\", "_")
        }

        # get maps options
        dialog.add_action_callback("get_maps_options") { |action_context, image_width, image_height, maps_array, composite|
            $image_width = image_width
            $image_height = image_height            
            $maps_array = maps_array
            $composite = composite
        }

        # export button
        dialog.add_action_callback("export_image_maps") { |action_context|
            if $output_folder === ""
                UI.messagebox('Select an output folder')
            elsif $export_name === ""
                UI.messagebox('Insert a name')
            elsif $image_width === nil || $image_height === nil
                UI.messagebox('Set image size')
            elsif $maps_array === []
                UI.messagebox('Select at least one map')
            else
                export_image_maps($maps_array, $image_width, $image_height, $composite)
            end
        }

    end

    # add custom styles from folder
    def self.load_custom_styles()
        # existing styles
        existing_styles_names = []
        Sketchup.active_model.styles.each{ |s| existing_styles_names.push(s.name) }

        # new styles
        new_styles_file_paths = Dir.glob(File.join(File.dirname(__FILE__), '/styles/*.style')).select{ |f| File.file? f }
        new_styles_names = []
        new_styles_file_paths.each{ |f| new_styles_names.push(f.split('/')[-1].split('.')[0]) }

        count = 0
        new_styles_file_paths.each{ |i|
            # if new style doesn't already exist, add it
            if( (existing_styles_names.include? new_styles_names[count]) == false)
                Sketchup.active_model.styles.add_style(i, false)
            end

            count += 1
        }
    end

    # Function to set output directory
    def self.set_output_dir()

        user_url = Dir.home

        # Choose folder to save file
        chosen_folder = UI.select_directory(
            title: "Select Image Directory",
            directory: user_url + "\\Pictures",
            select_multiple: false
          )

        return chosen_folder
    end

    # Function to export image maps
    def self.export_image_maps(maps_array, image_width = 3000, image_height = 2000, composite)

        # save style info before export
        active_style_name = Sketchup.active_model.styles.active_style.name

        # save shadow info before export
        shadow_info = Sketchup.active_model.shadow_info
        shadow_active = Sketchup.active_model.shadow_info["DisplayShadows"]

        # temporary disable shadows
        Sketchup.active_model.shadow_info["DisplayShadows"] = false

        # export
        if composite
            system("mkdir #{$output_folder.gsub("/", "\\")}\\maps")
        end

        maps_array.each{ |m|
            if (m == "shadows_map")
                Sketchup.active_model.shadow_info["DisplayShadows"] = true
            else
                Sketchup.active_model.shadow_info["DisplayShadows"] = false      
            end
            style = Sketchup.active_model.styles[m]
            if composite
                style_string = $output_folder + "/maps/" + $export_name + "_#{style.name}.png"
            else
                style_string = $output_folder + "/" + $export_name + "_#{style.name}.png"
            end
            Sketchup.active_model.styles.selected_style = style
            Sketchup.active_model.active_view.write_image(style_string, image_width, image_height, true)
        }

        # reset style and shadows as saved before export
        Sketchup.active_model.styles.selected_style = Sketchup.active_model.styles[active_style_name]
        Sketchup.active_model.shadow_info["DisplayShadows"] = shadow_active

        if composite
            composite_image_maps(maps_array)
        end
    end

    # Function to composite image maps
    def self.composite_image_maps(maps_array)

        background_string = $output_folder + "/maps/background.png"
        system("magick convert -size #{$image_width}x#{$image_height} xc:#ffffff #{background_string}")

        # check if ao exists
        if (maps_array.include? "ambientocclusion_map")
            $ambientocclusion_exist = true
        end
        
        # check if bool exists
        if (maps_array.include? "boolean_map")
            $boolean_exist = true
        end

        # edit maps before composition
        maps_array.each{ |m|

            style = Sketchup.active_model.styles[m]
            style_string = $output_folder + "/maps/" + $export_name + "_#{style.name}.png"
            
            # adaptive blur amount
            shadows_blur_sigma = (($image_width * $image_height) / 600000).floor()

            # blur and dissolve shadows map          
            if (m == "shadows_map")
                system("cd \\")
                # blur
                system("magick convert #{style_string} -blur 0x#{shadows_blur_sigma} #{style_string}")   
                # set transparency to 30%
                system("magick composite -dissolve 30 #{style_string} #{background_string} #{style_string}")

            # dissolve edges map          
            elsif (m == "edges_map")
                system("cd \\")
                # set transparency to 10%
                system("magick composite -dissolve 10 #{style_string} #{background_string} #{style_string}")
       
            # dissolve profiles map          
            elsif (m == "profiles_map")
                system("cd \\")
                # set transparency to 10%
                system("magick composite -dissolve 10 #{style_string} #{background_string} #{style_string}")
            end
        }

        # if one of ao map and bool map doesn't exist, remove both of them from the array
        if ($ambientocclusion_exist && $boolean_exist)

            background_string = $output_folder + "/maps/background.png"

            image_ao = $output_folder + "/maps/" + $export_name + "_ambientocclusion_map.png"
            image_bool = $output_folder + "/maps/" + $export_name + "_boolean_map.png"
            image_cmp = $output_folder + "/maps/" + $export_name + "_fixedambientocclusion_map.png"

            # adaptive blur amount
            ambientocclusion_blur_sigma = (($image_width * $image_height) / 150000).floor()

            # blur and dissolve ambient occlusion map
            system("cd \\")
            # blur
            system("magick convert #{image_ao} -blur 0x#{ambientocclusion_blur_sigma} #{image_ao}")
            # set transparency to 10%
            system("magick composite -dissolve 10 #{image_ao} #{background_string} #{image_ao}")

            # invert boolean map
            system("cd \\")
            system("magick convert #{image_bool} -negate #{image_bool}")

            # subtract bool from ambient occlusion
            system("cd \\")
            system("magick composite #{image_ao} #{background_string} #{image_bool} #{image_cmp}")

            system("del #{$output_folder.gsub("/", "\\") + "\\maps\\" + $export_name.gsub("/", "\\") + "_boolean_map.png"}")
            system("del #{$output_folder.gsub("/", "\\") + "\\maps\\" + $export_name.gsub("/", "\\") + "_ambientocclusion_map.png"}")

            maps_array.pop()
            maps_array.pop()

            maps_array.unshift("fixedambientocclusion_map")

        else
            if $ambientocclusion_exist
                maps_array.pop()
                system("del #{$output_folder.gsub("/", "\\") + "\\maps\\" + $export_name.gsub("/", "\\") + "_ambientocclusion_map.png"}")
            end
            if $boolean_exist
                maps_array.pop()
                system("del #{$output_folder.gsub("/", "\\") + "\\maps\\" + $export_name.gsub("/", "\\") + "_boolean_map.png"}")
            end
        end

        # iterate over maps array if there are at least two elements
        i = 0
        if (maps_array.length() == 1)
            image_file_src = $output_folder + "/maps/" + $export_name + "_#{maps_array[i]}.png"
            system("cd \\")
            system("move /Y #{image_file_src.gsub("/", "\\")} #{$output_folder.gsub("/", "\\")}")
            system("rename #{$output_folder.gsub("/", "\\") + "\\" + $export_name + "_" + maps_array[i]}.png #{$export_name}.png")
        else
            while i < (maps_array.length() - 1) do

                image_file_src = $output_folder + "/maps/" + $export_name + "_#{maps_array[i]}.png"
                image_file_dst = $output_folder + "/maps/" + $export_name + "_#{maps_array[i + 1]}.png"

                system("cd \\")
                system("magick composite #{image_file_src} #{image_file_dst} -compose Multiply #{image_file_dst}")

                # rename if last element
                if (i == maps_array.length() - 2) then
                    system("cd \\")
                    system("move /Y #{image_file_dst.gsub("/", "\\")} #{$output_folder.gsub("/", "\\")}")
                    system("rename #{$output_folder.gsub("/", "\\") + "\\" + $export_name + "_" + maps_array[i + 1]}.png #{$export_name}.png")
                end

                i += 1
            end
        end

        # delete maps
        system("cd \\")
        system("rmdir /Q /S -r #{$output_folder.gsub("/", "\\")}\\maps")

        $ambientocclusion_exist = false
        $boolean_exist = false
    end

    unless file_loaded?(__FILE__)

      menu = UI.menu('View')
      menu.add_item('Advanced View Export') {
        self.main()
      }

      self.load_custom_styles()

      file_loaded(__FILE__)
    end

  end # module AdvancedViewExport
end # module MattiaBressanelli
