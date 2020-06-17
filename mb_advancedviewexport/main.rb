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
    $boolean_exist = false
    $ambientocclusion_exist = false
    
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

        # set output folder
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
            $export_name = image_name
        }

        # get maps options
        dialog.add_action_callback("get_maps_options") { |action_context, image_width, image_height, maps_array, composite |
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
        files = Dir.glob(File.join(File.dirname(__FILE__), '/styles/*.style')).select{ |f| File.file? f }
        files.each{ |i| 
            Sketchup.active_model.styles.add_style(i, false)
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
        maps_array.each{ |m|
            if (m == "shadows_map")
                Sketchup.active_model.shadow_info["DisplayShadows"] = true
            else
                Sketchup.active_model.shadow_info["DisplayShadows"] = false      
            end
            style = Sketchup.active_model.styles[m]
            style_string = $output_folder + "/" + $export_name + "_#{style.name}.png"
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

        background_string = $output_folder + "/background.png"
        system("magick convert -size #{$image_width}x#{$image_height} xc:#ffffff #{background_string}")

        # adaptive blur amount
        ambientocclusion_blur_sigma = (($image_width * $image_height) / 150000).floor()
        shadows_blur_sigma = (($image_width * $image_height) / 600000).floor()

        # edit maps before composition
        maps_array.each{ |m| 

            style = Sketchup.active_model.styles[m]
            style_string = $output_folder + "/" + $export_name + "_#{style.name}.png"

            # blur and dissolve ambient occlusion map
            if (m == "ambientocclusion_map")
                $ambientocclusion_exist = true

                system("cd \\")
                # blur
                system("magick convert #{style_string} -blur 0x#{ambientocclusion_blur_sigma} #{style_string}")
                # set transparency to 10%
                system("magick composite -dissolve 10 #{style_string} #{background_string} #{style_string}")

            # invert boolean map
            elsif (m == "boolean_map")
                $boolean_exist = true

                system("cd \\")
                system("magick convert #{style_string} -negate #{style_string}")

            # blur and dissolve shadows map          
            elsif (m == "shadows_map")
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

        if ($ambientocclusion_exist == false || $boolean_exist == false)
            i = 0
            while i < (maps_array.length() - 1) do
                if (maps_array[i] == "boolean_map")
                    maps_array.slice(i, 1)   
                end
            end

            i = 0
            while i < (maps_array.length() - 1) do
                if (maps_array[i] == "ambientocclusion_map")
                    maps_array.slice(i, 1)
                end
            end

        # if both exist
        else
            image_ao = $output_folder + "/" + $export_name + "_ambientocclusion_map.png"
            image_bool = $output_folder + "/" + $export_name + "_boolean_map.png"
            image_cmp = $output_folder + "/" + $export_name + "_fixedambientocclusion_map.png"

            system("cd \\")
            system("magick composite #{image_ao} #{background_string} #{image_bool} #{image_cmp}")

            maps_array.pop()
            maps_array.pop()

            maps_array.unshift("fixedambientocclusion_map")
        end

        # iterate over maps array

        i = 0
        while i < (maps_array.length() - 1) do

            image_file_src = $output_folder + "/" + $export_name + "_#{maps_array[i]}.png"
            image_file_dst = $output_folder + "/" + $export_name + "_#{maps_array[i + 1]}.png"

            system("cd \\")
            system("magick composite #{image_file_src} #{image_file_dst} -compose Multiply #{image_file_dst}")

            # rename if last element
            if (i == maps_array.length() - 2) then
                system("cd \\")
                image_file_dst_rev = image_file_dst.gsub("/", "\\")
                system("rename #{image_file_dst_rev} #{$export_name}.png")
            end

        i += 1
        end

        # delete maps
        system("cd \\")
        background_string_rev = background_string.gsub("/", "\\")
        system("del #{background_string_rev}")

        output_folder_rev = $output_folder.gsub("/", "\\")

        image_to_delete = output_folder_rev + "\\" + $export_name + "_ambientocclusion_map.png"
        system("cd \\")
        system("del #{image_to_delete}")
        
        image_to_delete = output_folder_rev + "\\" + $export_name + "_boolean_map.png"
        system("cd \\")
        system("del #{image_to_delete}")

        i = 0
        while i < (maps_array.length() - 1) do
            image_to_delete = output_folder_rev + "\\" + $export_name + "_#{maps_array[i]}.png"
            system("cd \\")
            system("del #{image_to_delete}")
        i += 1
        end
    
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
