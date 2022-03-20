
package provide svgconvert 1.0

namespace eval ::svgconvert {
    # collect all the include directories
    catch {
        package require critcl
    }

    if {[info command ::critcl::compiling] ne "" && [critcl::compiling]} {
        catch {
        set options [regsub -all -- -I [exec pkg-config --cflags --libs cairo --libs librsvg-2.0] "I "]
        set dirs [list]
        foreach {i dir} $options {
            if {$i eq "I"} {
                lappend dirs $dir
            }
        }
        critcl::clibraries -lrsvg-2 -lm -lgio-2.0 -lgdk_pixbuf-2.0 -lgobject-2.0 -lglib-2.0 -lcairo -pthread
        critcl::config I $dirs
        critcl::ccode {
            #include <string.h>
            #include <stdio.h>
            #include <cairo.h>
            #include <cairo/cairo-pdf.h>
            #include <cairo/cairo-svg.h>        
            #include <librsvg/rsvg.h>
        }
        
        
        critcl::cproc svgconvert {char* svgfile  char* outfile double scalex double scaley} void {
            // new
            char *epdf = ".pdf";
            char *esvg = ".svg";
            char *pdf = strstr(outfile, epdf);
            char *svg = strstr(outfile, esvg);    
            
            RsvgHandle *handle;
            //RsvgDimensionData dimension_data; // deprecated
            gdouble width = 0.0;
            gdouble height = 0.0;
            GError* err = NULL;
            handle = rsvg_handle_new_from_file(svgfile, &err);
            
            if (err != NULL) {
                fprintf(stderr, "libsvgconv: Failed to load svg: '%s'; %s\n", svgfile, (char*) err->message);
                g_error_free(err);
                err = NULL;
            }
            
            cairo_surface_t *surface;
            cairo_t *ctx;
            
            //rsvg_handle_get_dimensions(handle, &dimension_data); // deprecated
            rsvg_handle_get_intrinsic_size_in_pixels(handle,&width, &height);
            double resx = width*scalex ; //((double) dimension_data.width) * scalex;
            double resy = height*scaley; //((double) dimension_data.height) * scaley;
            if (pdf) {
                surface = cairo_pdf_surface_create(outfile, (int) resx, (int) resy); 
            } else if (svg) {
                surface = cairo_svg_surface_create(outfile, (int) resx, (int) resy); 
            } else {
                surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, (int) resx, (int) resy);
            }
            ctx = cairo_create(surface);
            
            cairo_set_source_rgba(ctx, 255, 255, 255, 0);
            //cairo_scale(ctx, scalex, scaley);
            RsvgRectangle viewport = {
                .x = 0.0,
                .y = 0.0,
                .width = resx,
                .height = resy,
            };
            //rsvg_handle_render_cairo(handle, ctx); // deprecated
            rsvg_handle_render_document(handle,ctx,&viewport,NULL);
            cairo_paint(ctx);
            cairo_show_page(ctx);
            cairo_destroy(ctx);
            // Destroying cairo context
            cairo_surface_flush(surface);
            if (pdf || svg) {
                // Destroying PDF surface
                cairo_surface_destroy(surface);
            } else {
                cairo_surface_write_to_png(surface, outfile);
                cairo_surface_destroy(surface);
            } 
        }
        proc svgconv {infile outfile {scalex 1.0} {scaley 1.0}} {
            if {$scalex != $scaley} {
                set scaley $scalex
            }
            if {![file exists $infile]} {
                error "Error: File $infile does not exist!"
            }
            svgconvert::svgconvert $infile $outfile $scalex $scaley
        }
        }
    } 
    if {[info command ::svgconvert::svgconv] eq "" && [auto_execok rsvg-convert] ne ""} {
        proc svgconv {infile outfile {scalex 1.0} {scaley 1.0}} {
            if {$scalex != $scaley} {
                set scaley $scalex
            }
            if {![file exists $infile]} {
                error "Error: File $infile does not exist!"
            }
            exec rsvg-convert $infile -o $outfile -z $scalex
        }
    } elseif {[info command ::svgconvert::svgconv] eq "" && [auto_execok cairosvg] ne ""} {
        proc svgconv {infile outfile {scalex 1.0} {scaley 1.0}} {
            if {$scalex != $scaley} {
                set scaley $scalex
            }
            if {![file exists $infile]} {
                error "Error: File $infile does not exist!"
            }
            exec cairosvg -f [string range [string tolower [file extension $outfile]] 1 end] -o $outfile -s $scalex $infile 
        }
    } elseif {[info command ::svgconvert::svgconv] eq ""}  {
        puts stderr "Error: no svg conversion available neither critcl and librsvg2-dev or the terminal applications rsvg-convert or cairosvg are available! Please install"
    }
        
    proc svg2svg {svginfile svgoutfile {scalex 1.0} {scaley 1.0}} {
        if {[file extension $svgoutfile] ne ".svg"} {
            error "Error: File extension for $svgoutfile is not .svg!"
        }
        svgconv $svginfile $svgoutfile $scalex $scaley
    }
    proc svg2pdf {svgfile pdffile {scalex 1.0} {scaley 1.0}} {
        if {[file extension $pdffile] ne ".pdf"} {
            error "Error: File extension for $pdffile is not .pdf!"
        }
        svgconv $svgfile $pdffile $scalex $scaley
    }
    proc svg2png {svgfile pngfile {scalex 1.0} {scaley 1.0}} {
        if {[file extension $pngfile] ne ".png"} {
            error "Error: File extension for $pngfile is not .png!"
        }
        svgconv $svgfile $pngfile $scalex $scaley
    }
    proc svgimg {type {src ""}} {
        if {$src eq ""} {
            set src $type
            set type "-file"
        }
        if {$type eq "-file"} {
            if {![regexp -nocase {\.svg$} $src]} {
                error "Only svg files can be converted"
            }
            set tmpfile [file tempfile].png
            svg2png $src $tmpfile
            set img [image create photo -file $tmpfile]
            $img write $tmpfile -background white
            set img [image create photo -file $tmpfile]
            file delete $tmpfile
            return $img
        } elseif {$type eq "-data"} {
            set svgfile [file tempfile].svg
            set out [open $svgfile w 0600]
            puts $out [binary decode base64 $src]
            close $out
            set img [svgimg -file $svgfile]
            file delete $svgfile
            return $img
        }
        
    }
    proc svg2base64 {filename} {
        if [catch {open $filename r} infh] {
            puts stderr "Cannot open $filename: $infh"
        } else {
            set lines [read $infh]
            set b64 [binary encode base64 $lines]
            close $infh
            return $b64
        }
    }
    proc base642svg {base64 filename} {
        set svgfile $filename
        set out [open $svgfile w 0600]
        puts $out [binary decode base64 $base64]
        close $out
    }
    namespace export svg2pdf svg2png svg2svg svgimg svg2base64
}

if {$argv0 eq [info script]} {
    namespace import svgconvert::*
    # just for timing
    foreach i [list 1 2 3 4 5 6] {
        svg2svg samples/basic-shapes.svg samples/basic-shapes-out.svg 0.5
        svg2pdf samples/basic-shapes.svg samples/basic-shapes-out.pdf 0.5
        svg2png samples/basic-shapes.svg samples/basic-shapes-out.png 0.5
        svg2png samples/basic-shapes.svg samples/basic-shapes-out-large.png 2.0    
    }
    package require Tk
    set f [frame .fr -background white]
    set img [svgimg samples/basic-shapes.svg]
    pack [ttk::label .fr.lbl -image $img -border 0] -side left  -padx 10 -pady 10
    set b64 "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiIHN0YW5kYWxvbmU9InllcyI/PgogICAgPHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgaGVpZ2h0PSIyNTAiIHdpZHRoPSIyMDAiPgoKPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMzAiIGhlaWdodD0iMzAiIHN0cm9rZT0iYmxhY2siIGZpbGw9InRyYW5zcGFyZW50IiBzdHJva2Utd2lkdGg9IjUiIC8+Cgo8cmVjdCB4PSI2MCIgeT0iMTAiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMzAiIGhlaWdodD0iMzAiIHN0cm9rZT0iYmxhY2siIGZpbGw9InRyYW5zcGFyZW50IiBzdHJva2Utd2lkdGg9IjUiIC8+Cgo8Y2lyY2xlIGN4PSIyNSIgY3k9Ijc1IiByPSIyMCIgc3Ryb2tlPSJyZWQiIGZpbGw9InRyYW5zcGFyZW50IiBzdHJva2Utd2lkdGg9IjUiIC8+Cgo8ZWxsaXBzZSBjeD0iNzUiIGN5PSI3NSIgcng9IjIwIiByeT0iNSIgc3Ryb2tlPSJyZWQiIGZpbGw9InRyYW5zcGFyZW50IiBzdHJva2Utd2lkdGg9IjUiIC8+Cgo8bGluZSB4MT0iMTAiIHgyPSI1MCIgeTE9IjExMCIgeTI9IjE1MCIgc3Ryb2tlPSJvcmFuZ2UiIHN0cm9rZS13aWR0aD0iNSIgLz4KCjxwb2x5bGluZSBwb2ludHM9IjYwICAxMTAgNjUgMTIwIDcwIDExNSA3NSAxMzAgODAgMTI1IDg1IDE0MCA5MCAxMzUgOTUgMTUwIDEwMCAxNDUiIHN0cm9rZT0ib3JhbmdlIiBmaWxsPSJ0cmFuc3BhcmVudCIgc3Ryb2tlLXdpZHRoPSI1IiAvPgoKPHBvbHlnb24gcG9pbnRzPSI1MCAgMTYwIDU1IDE4MCA3MCAxODAgNjAgMTkwIDY1IDIwNSA1MCAxOTUgMzUgMjA1IDQwIDE5MCAzMCAxODAgNDUgMTgwIiBzdHJva2U9ImdyZWVuIiBmaWxsPSJ0cmFuc3BhcmVudCIgc3Ryb2tlLXdpZHRoPSI1IiAvPgoKPHBhdGggZD0iTTIwLDIzMCAgUTQwLDIwNSA1MCwyMzBUOTAsMjMwIiBmaWxsPSJub25lIiBzdHJva2U9ImJsdWUiIHN0cm9rZS13aWR0aD0iNSIgLz4KCjwvc3ZnPgo="
    set img2 [svgimg -data $b64]
    pack [ttk::label .fr.lbl2 -image $img2 -border 0] -side left -padx 10 -pady 10
    pack $f -side top -fill both -expand true
    #exit 0
}
