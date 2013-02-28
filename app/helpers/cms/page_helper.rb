module Cms

  module DeprecatedBehavior

    # Add the code to render the CMS toolbar.
    # @deprecated This method is no longer required for BrowserCMS templates.
    def cms_toolbar
      ActiveSupport::Deprecation.warn "The cms_toolbar helper is deprecated and no longer necessary. You can safely remove <%= cms_toolbar %> from templates.", caller
      return ""
    end
  end

  module PageHelper
    include Cms::DeprecatedBehavior

    # Keep this taller until we reverse the iframes (so menus will work)
    PAGE_TOOLBAR_HEIGHT = 159
    TOOLBAR_HEIGHT = 100

    # Return the JS file to load the configured default WYSIWYG editor
    #
    # Ideally, this could be improved if sprockets allows for dynamically determining which js library to use.
    # @return [Array] Names of the JS files need to load the editor.
    def cms_content_editor
      if Cms.content_editor.is_a?(Array)
        Cms.content_editor
      else
        "bcms/#{Cms.content_editor}" # Handles existing FCKEditor behavior
      end
    end

    # Outputs the title for this page. Used by both internal CMS pages, as well as page templates. If not explicitily set,
    #   returns the title of the page.
    #
    # @TODO - Should split this into two methods page_title= to avoid complicated logic.
    # @param [String] page_title The name this page should be set to.
    # @param [String] options Options for the page title
    # @return [String] The title of the page.
    def page_title(*args)
      if args.first
        @page_title = args.first
      else
        @page_title ? @page_title : current_page.page_title
      end
    end

    # Returns the Page title in an In Context editable area.
    #
    # Use for h1/h2 elements. Use page_title for title elements.
    def editable_page_title()
      options = {id: 'page_title', contenteditable: true, data: { attribute: "title", content_name: "page", id: current_page.id, page_id: current_page.id}}
      content_tag "div", page_title, options
    end


    def current_page
      @page
    end

    # Outputs the content of a particular container. If the user is in 'edit' mode the container and block controls will
    # be rendered.
    #
    # @return [String] The HTML content for the container.
    def container(name)
      content = content_for(name)

      if logged_in? && @page && current_user.able_to_edit?(@page)
        render :partial => 'cms/pages/simple_container', :locals => {:name => name, :content => content}
      else
        content
      end
    end    
    # Determine if a given container has any blocks within it. Useful for determine if markup should be conditionally included
    # when a block is present, but not shown if no block was added. For example:
    #
    # <% unless container_has_block? :sidebar %>
    #   <div id="sidebar">
    #   <%= container :sidebar %>
    #   </div>
    # <% end %>
    #
    # @param [Symbol] name The name of the container to check
    # @param [Proc] block
    # @return [Boolean] True if the container has one or more blocks, or if we are in edit mode. False otherwise. 
    def container_has_block?(name, &block)
      has_block = (@mode == "edit") || current_page.connectable_count_for_container(name) > 0
      logger.info "mode = #{@mode}, has_block = #{has_block}"
      if block_given?
        concat(capture(&block)) if has_block
      else
        has_block
      end
    end

    # Renders breadcrumbs based on the current_page. This will generate an unordered list representing the
    # current page and all it's ancestors including the root name of of the site. The UL can be styled via CSS for
    # layout purposes. Each breadcrumb except the last will be linked to the page in question.
    #
    # If the current_page is nil, it will return an empty string.
    #
    # ==== Params:
    #   options = A hash of options which determine how the breadcrumbs will be laid out.
    #
    # ==== Options:
    # * <tt>:from_top</tt> - How many below levels from the root the tree should start at.
    #   All sections at this level will be shown.  The default is 0, which means show all
    #   nodes that are direct children of the root.
    # * <tt>:show_parent</tt> - Determines if the name of the page itself show be shown as a breadcrumb link. Defaults to false, meaning
    #   that the parent section of the current page will be the 'last' breadcrumb link. (Note: This probably better renamed as 'show_page').
    #
    def render_breadcrumbs(options={})
      return "" unless current_page

      start = options[:from_top] || 0
      show_parent = options[:show_parent].nil? ? false : options[:show_parent]
      ancestors = current_page.ancestors
      items = []
      ancestors[start..ancestors.size].each_with_index do |sec,i|
        items << content_tag(:li, 
          link_to(sec.name, sec.actual_path), (i == 0 ? {:class => "first"} : {}))
      end
      if !show_parent && current_page.section.path == current_page.path
        items[items.size-1] = content_tag(:li, current_page.section.name)
      else
        items << content_tag(:li, current_page.page_title)
      end
      content_tag(:ul, "\n  #{items.join("\n  ")}\n".html_safe, :class => "breadcrumbs")
    end
    
    def render_portlet(name)
      portlets = Portlet.all(:conditions => ["name = ?", name.to_s])
      if portlets.size > 1
        @mode == "edit" ? "ERROR: Multiple Portlets with name '#{name}'" : nil
      elsif portlets.empty?
        @mode == "edit" ? "ERROR: No Portlet with name '#{name}'" : nil
      else
        render_connectable(portlets.first)
      end
    end

    # Determines if the current_user is able to do specific permissions.
    def able_to?(*perms, &block)
      block.call if current_user.able_to?(*perms)
      return ''
    end

  end
end
