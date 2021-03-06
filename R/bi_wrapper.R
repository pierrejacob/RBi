#' @rdname bi_wrapper
#' @name bi_wrapper
#' @title Bi Wrapper
#' @description
#' \code{bi_wrapper} allows to call \code{libbi}.
#' Upon creating a new bi_wrapper object, the following arguments can be given.
#' Once the instance is created, \code{libbi} can be run through the \code{run}
#' method documented in \code{\link{bi_wrapper_run}}.
#' 
#' @param client is either "draw", "filter", "sample"... see LibBi documentation.
#' @param model_file_name path to a model file (typically ending in ".bi"); libbi will be executed from within the same folder.
#' @param config path to a configuration file, containing multiple arguments
#' @param global_options additional arguments to pass to the call to \code{libbi}, on top of the ones in the config file
#' @param working_folder path to a folder from which to run \code{libbi}; default to the folder where model_file_name is.
#' @param path_to_libbi path to \code{libbi} binary; by default it tries to locate \code{libbi}
#' using the \code{which} Unix command, after having loaded "~/.bashrc" if present; 
#' if unsuccessful it tries "~/PathToBiBin/libbi"; if unsuccessful again it fails.
#' @examples
#' bi_object <- bi_wrapper$new(client = "sample",
#'                             model_file_name = system.file(package="bi", "PZ.bi"), 
#'                             global_options = "--sampler smc2")
#' @seealso \code{\link{bi_wrapper_run}}
#' @export bi_wrapper
NULL 
#' @rdname bi_wrapper_run
#' @name bi_wrapper_run
#' @aliases bi_wrapper_run  bi_run  libbi
#' @title Using the Bi Wrapper to Launch LibBi
#' @description
#' The method \code{run} of an instance of \code{\link{bi_wrapper}}
#' allows to launch \code{libbi} with a particular set of command line
#' arguments. 
#'
#' @param add_options additional arguments to pass to the call to \code{libbi}
#' @param output_file_name path to the result file (which will be overwritten)
#' @param stdoutput_file_name path to a file to text file to report the output of \code{libbi}
#' @return a list containing the absolute paths to the results; it is stored in the 
#' \code{result} field of the instance of \code{\link{bi_wrapper}}.
#' @seealso \code{\link{bi_wrapper}}
#' @examples
#' bi_object <- bi_wrapper$new(client = "sample",
#'                             model_file_name = system.file(package="bi", "PZ.bi"), 
#'                             global_options = "--sampler smc2")
#' bi_object$run(add_options=" --verbose --nthreads 1")
#' bi_file_summary(bi_object$result$output_file_name)
NULL 

bi_wrapper <- setRefClass("bi_wrapper",
      fields = c("client", "config", "global_options", "path_to_libbi", 
                 "model_file_name", "model_folder", "rel_model_file_name", 
                 "base_command_string", "command", "command_dryparse", "result",
                 "working_folder", "output_file_name"),
      methods = list(
        initialize = function(client, model_file_name,
                              config, global_options, path_to_libbi,
                              working_folder, result){
          result <<- list()
          if (missing(client)){
            print("you didn't provide a 'client' to bi_wrapper, it's kinda weird; default to 'sample'.")
            client <<- "sample"
          } else {
            client <<- client
          }
          if (missing(model_file_name)){
            stop("you need to provide 'model_file_name', a path to a valid model file in LibBi's syntax")
          } else {
            model_file_name <<- absolute_path(model_file_name)
            model_folder <<- dirname(model_file_name)
            rel_model_file_name <<- basename(model_file_name)
          }
          if (missing(working_folder)){
            working_folder <<- model_folder
          } else {
            working_folder <<- working_folder
            # then we have to change rel_model_file_name again
            rel_model_file_name <<- .self$model_file_name
          }
          if (missing(config)){
            config <<- ""
          } else {
            config <<- paste0(" @", absolute_path(filename=config, dirname=model_folder))
          }
          if (missing(global_options))
            global_options <<- ""
          else 
            global_options <<- global_options
          if (missing(path_to_libbi)){
            # That's a bit tricky then because we really need to know where libbi is.
            # Maybe the system knows where libbi is
            path_to_libbi <<- suppressWarnings(system("which libbi", TRUE))
            if (length(.self$path_to_libbi) == 0){
              # Else try to get the path to libbi from a folder called PathToBiBin
              # created by the user with a command like 'ln -s actual_path ~/PathToBiBin'.
              path_to_libbi <<- try(tools::file_path_as_absolute("~/PathToBiBin/libbi"), TRUE)
              if (inherits(.self$path_to_libbi, "try-error")){
                # then we can try to find libbi if there's a path in the bashrc file
                bashrc <- try(system("cat ~/.bashrc", intern = TRUE), TRUE)
                if (length(bashrc) > 0){
                  # there is a bashrc file so we will read the exports from it
                  lineswithPATH <- bashrc[stringr::str_detect(bashrc, "PATH")]
                  exportPath <- lineswithPATH[stringr::str_detect(lineswithPATH, "export")]
                  exportPath <- lineswithPATH[stringr::str_sub(exportPath, start=1, end=1) != "#"]
                  exportPathcmd <- paste(exportPath, collapse=";")
                  # then we execute the export commands and try to locate libbi
                  path_to_libbi <<- system(gsub(";;", ";", 
                                               paste(exportPathcmd, "which libbi", sep = ";")),
                                          intern<-TRUE)
                }
              }
            }
          } else {
            # check that the user provided a path to an existing file
            path_to_libbi <<- tools::file_path_as_absolute(.self$path_to_libbi)
          }
          base_command_string <<- paste(.self$path_to_libbi, .self$client,
                                        "--model-file", .self$rel_model_file_name,
                                        .self$config,
                                        .self$global_options)
        },
        run = function(add_options, output_file_name, stdoutput_file_name){
          if (missing(add_options)){
            add_options <- ""
          }
          if (missing(output_file_name)){
            output_file_name <<- tempfile(pattern="output_file_name", fileext=".nc")
          } else {
            output_file_name <<- output_file_name 
          }
          if (missing(stdoutput_file_name)){
            stdoutput_file_name <- ""
          } else {
            stdoutput_file_name <- paste("2>", stdoutput_file_name)
          }
          cdcommand <- paste("cd", .self$working_folder)
          launchcommand <- paste(.self$base_command_string, add_options,
                                 "--output-file", .self$output_file_name)
          print("Launching LibBi with the following commands:")
          print(paste(c(cdcommand, launchcommand, stdoutput_file_name), sep = "\n"))
          command <<- paste(c(cdcommand, paste(launchcommand, stdoutput_file_name)), collapse = ";")
#           command_dryparse <<- paste(c(cdcommand, paste(launchcommand, "--dry-parse")), collapse = ";")
          system(command, intern = TRUE)
          print("... LibBi has finished!")
          libbi_result <- list(output_file_name = absolute_path(filename=.self$output_file_name, 
                                                  dirname=.self$working_folder),
                               model_file_name = .self$model_file_name)
          if (!missing(stdoutput_file_name)){
            libbi_result["stdoutput_file_name"] = absolute_path(filename=stdoutput_file_name, dirname=.self$model_file_name)
          }
          result <<- libbi_result
        },
        rerun = function(add_options){
          if (missing(add_options)){
            add_options <- ""
          }
          cdcommand <- paste("cd", .self$working_folder)
          launchcommand <- paste(.self$base_command_string, add_options,
                                 "--output-file", .self$output_file_name)
          command_dryparse <<- paste(c(cdcommand, paste(launchcommand, "--dry-parse")), collapse = ";")
          print("Launching LibBi with the following commands:")
          print(.self$command_dryparse)
          system(.self$command_dryparse, intern = TRUE)
          print("... LibBi has finished!")
        },
        show = function(){
          cat("Wrapper around LibBi\n")
          cat("* client: ", .self$client, "\n")
          cat("* path to working folder:", .self$working_folder, "\n")
          cat("* path to model file:", .self$model_file_name, "\n")
          cat("* path to LibBi binary:", .self$path_to_libbi, "\n")
        }
        )
      )


