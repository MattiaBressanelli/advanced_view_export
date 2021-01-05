# This extension creates maps for edges, color, profiles, shadows ecc. and combines them into an image.

require 'sketchup.rb'

module MattiaBressanelli
  module AdvancedViewExport

    # parameters
    class Parameters

        attr_accessor :output_folder, :export_name, :image_width, :image_height, :maps_array, :composite, :ambientocclusion_exist, :boolean_exist

        def initialize()
            @output_folder = ""
            @export_name = ""
            @image_width = nil
            @image_height = nil
            @maps_array = []
            @composite
            @ambientocclusion_exist = false
            @boolean_exist = false
        end

        def to_s()
            return ["#{@output_folder}", "#{@export_name}", "#{@image_width}", "#{@image_height}", "#{@maps_array}", "#{@composite}", "#{@ambientocclusion_exist}", "#{@boolean_exist}"]
        end
    end
    
    # Main function
    def self.main()

        # initialize parameters
        parameters = Parameters.new()
       
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
            parameters.output_folder = set_output_dir()
            if parameters.output_folder === nil
                parameters.output_folder = ""
            end
            js_command = "document.getElementById('output-folder').value = '" + parameters.output_folder + "'"
            dialog.execute_script(js_command)
        }

        # get image name
        dialog.add_action_callback("get_image_name") { |action_context, image_name|
            parameters.export_name = image_name.gsub(" ", "_").gsub(".", "_").gsub("/", "_").gsub("\\", "_").gsub("*", "_").gsub("?", "_").gsub(":", "_").gsub("<", "_").gsub(">", "_").gsub("|", "_").gsub("\"", "_")
        }

        # get maps options
        dialog.add_action_callback("get_maps_options") { |action_context, image_width, image_height, maps_array, composite|
            parameters.image_width = image_width
            parameters.image_height = image_height            
            parameters.maps_array = maps_array
            parameters.composite = composite
        }

        # export button
        dialog.add_action_callback("export_image_maps") { |action_context|
            if parameters.output_folder === ""
                UI.messagebox('Select an output folder')
            elsif parameters.export_name === ""
                UI.messagebox('Insert a name')
            elsif parameters.image_width === nil || parameters.image_height === nil
                UI.messagebox('Set image size')
            elsif parameters.maps_array === []
                UI.messagebox('Select at least one map')
            else
                export_image_maps(parameters, dialog)
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
    def self.export_image_maps(parameters, dialog)

        # save style info before export
        active_style_name = Sketchup.active_model.styles.active_style.name

        # save shadow info before export
        shadow_info = Sketchup.active_model.shadow_info
        shadow_active = Sketchup.active_model.shadow_info["DisplayShadows"]

        # temporary disable shadows
        Sketchup.active_model.shadow_info["DisplayShadows"] = false

        # generate random number
        random_number = rand(1..100)

        # export
        if parameters.composite
            system("mkdir #{parameters.output_folder.gsub("/", "\\")}\\mb_ave_temp_#{random_number}")
        end

        parameters.maps_array.each{ |m|
            if (m == "shadows_map")
                Sketchup.active_model.shadow_info["DisplayShadows"] = true
            else
                Sketchup.active_model.shadow_info["DisplayShadows"] = false      
            end
            style = Sketchup.active_model.styles[m]
            if parameters.composite
                style_string = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_#{style.name}.png"
            else
                style_string = parameters.output_folder + "/" + parameters.export_name + "_#{style.name}.png"
            end
            Sketchup.active_model.styles.selected_style = style
            Sketchup.active_model.active_view.write_image(style_string, parameters.image_width, parameters.image_height, true)
        }

        # reset style and shadows as saved before export
        Sketchup.active_model.styles.selected_style = Sketchup.active_model.styles[active_style_name]
        Sketchup.active_model.shadow_info["DisplayShadows"] = shadow_active

        if parameters.composite
            composite_image_maps(parameters, random_number)
        end

        # end of operation
        dialog.close
    end
    
    # Function to composite image maps
    def self.composite_image_maps(parameters, random_number)

        background_string = parameters.output_folder + "/mb_ave_temp_#{random_number}/background.png"
        system("magick convert -size #{parameters.image_width}x#{parameters.image_height} xc:#ffffff #{background_string}")

        # check if ao exists
        if (parameters.maps_array.include? "ambientocclusion_map")
            parameters.ambientocclusion_exist = true
        end
        
        # check if bool exists
        if (parameters.maps_array.include? "boolean_map")
            parameters.boolean_exist = true
        end

        # edit maps before composition
        parameters.maps_array.each{ |m|

            style = Sketchup.active_model.styles[m]
            style_string = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_#{style.name}.png"
            
            # adaptive blur amount
            shadows_blur_sigma = ((parameters.image_width * parameters.image_height) / 600000).floor()

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
        if (parameters.ambientocclusion_exist && parameters.boolean_exist)

            background_string = parameters.output_folder + "/mb_ave_temp_#{random_number}/background.png"

            image_ao = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_ambientocclusion_map.png"
            image_bool = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_boolean_map.png"
            image_cmp = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_fixedambientocclusion_map.png"

            # adaptive blur amount
            ambientocclusion_blur_sigma = ((parameters.image_width * parameters.image_height) / 150000).floor()

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

            system("del #{parameters.output_folder.gsub("/", "\\") + "\\mb_ave_temp_#{random_number}\\" + parameters.export_name.gsub("/", "\\") + "_boolean_map.png"}")
            system("del #{parameters.output_folder.gsub("/", "\\") + "\\mb_ave_temp_#{random_number}\\" + parameters.export_name.gsub("/", "\\") + "_ambientocclusion_map.png"}")

            parameters.maps_array.pop()
            parameters.maps_array.pop()

            parameters.maps_array.unshift("fixedambientocclusion_map")

        else
            if parameters.ambientocclusion_exist
                parameters.maps_array.pop()
                system("del #{parameters.output_folder.gsub("/", "\\") + "\\mb_ave_temp_#{random_number}\\" + parameters.export_name.gsub("/", "\\") + "_ambientocclusion_map.png"}")
            end
            if parameters.boolean_exist
                parameters.maps_array.pop()
                system("del #{parameters.output_folder.gsub("/", "\\") + "\\mb_ave_temp_#{random_number}\\" + parameters.export_name.gsub("/", "\\") + "_boolean_map.png"}")
            end
        end

        # iterate over maps array if there are at least two elements
        i = 0
        if (parameters.maps_array.length() == 1)
            image_file_src = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_#{parameters.maps_array[i]}.png"
            system("cd \\")
            system("move /Y #{image_file_src.gsub("/", "\\")} #{parameters.output_folder.gsub("/", "\\")}")
            system("rename #{parameters.output_folder.gsub("/", "\\") + "\\" + parameters.export_name + "_" + parameters.maps_array[i]}.png #{parameters.export_name}.png")
        else
            while i < (parameters.maps_array.length() - 1) do

                image_file_src = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_#{parameters.maps_array[i]}.png"
                image_file_dst = parameters.output_folder + "/mb_ave_temp_#{random_number}/" + parameters.export_name + "_#{parameters.maps_array[i + 1]}.png"

                system("cd \\")
                system("magick composite #{image_file_src} #{image_file_dst} -compose Multiply #{image_file_dst}")

                # rename if last element
                if (i == parameters.maps_array.length() - 2) then
                    system("cd \\")
                    system("move /Y #{image_file_dst.gsub("/", "\\")} #{parameters.output_folder.gsub("/", "\\")}")
                    system("rename #{parameters.output_folder.gsub("/", "\\") + "\\" + parameters.export_name + "_" + parameters.maps_array[i + 1]}.png #{parameters.export_name}.png")
                end

                i += 1
            end
        end

        # delete maps
        system("cd \\")
        system("rmdir /Q /S -r #{parameters.output_folder.gsub("/", "\\")}\\mb_ave_temp_#{random_number}")

        parameters.ambientocclusion_exist = false
        parameters.boolean_exist = false
    end

    unless file_loaded?(__FILE__)

        # create menu entry
        extensions_menu = UI.menu('Extensions')
        submenu = extensions_menu.add_submenu("Mattia Bressanelli")
        submenu.add_item('Advanced View Export') {
            self.main()
        }

        # load styles
        self.load_custom_styles()

        file_loaded(__FILE__)
    end

  end # module AdvancedViewExport
end # module MattiaBressanelli
