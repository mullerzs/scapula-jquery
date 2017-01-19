(($) ->
  prefix = 'sc'

  utils = require 'scapula-utils'

  # ---- Helpers --------------------------------------------------------------

  helpers =
    WrapInDiv: (str) ->
      str ?= ''
      $('<div>' + str + '</div>')

    HtmlProcess: (str, opts) ->
      str ?= ''
      $node = $["#{prefix}WrapInDiv"] str

      funcs = opts?.funcs || []
      funcs = [ funcs ] if typeof(funcs) is 'string'

      $node[func]() for func in funcs
  
      $node.html()

    ForceBlur: ->
      type = if utils.isMobile() then 'month' else 'text'
      $('<input type="' + type + '"
          style="font-size: 16px; position: fixed; top: 0; left: -10000px">')
        .appendTo('body').focus().remove()

  $[prefix + name] = func for name, func of helpers

  # ---- Stateless plugins ----------------------------------------------------

  fns =
    OuterHtml: ->
      $(@).clone().wrap('<div></div>').parent().html()

    Checked: ->
      $(@).prop('checked') || ''

    InputVal: (val) ->
      prop = if @[0]?.nodeName?.toLowerCase() in [ 'input', 'textarea' ]
        'val'
      else
        'text'

      if val? then $(@)[prop](val) else $(@)[prop]()

    CleanHtml: ->
      txt = $(@).text()
      if $.trim txt
        $(@).html()
      else
        ''

    WrapInTag: (opts = {}) ->
      type = opts.type ? 'div'
      attrs = opts.attrs ? {}

      @each ->
        $tag = $(@).wrap("<#{type}>").parent()
        for key, val of attrs
          attr = if key is 'mailto'
            val = "mailto:#{val}"
            'href'
          else
            key
          $tag.attr attr, val

    GetCaretRange: (oe) ->
      x = oe?.clientX
      y = oe?.clientY

      if document.caretRangeFromPoint
        range = document.caretRangeFromPoint x, y if x? && y?
      else if document.createRange && oe?.rangeParent
        range = document.createRange()
        range.setStart oe.rangeParent, oe.rangeOffset
      range

    SetCaretToEnd: ->
      el = $(@).get(0)

      if el.nodeName.toLowerCase() in [ 'input', 'textarea' ]
        len = $(@).val().length
        el.setSelectionRange len, len
      else if window.getSelection? && document.createRange?
        range = document.createRange()
        range.selectNodeContents(el)
        range.collapse false
        sel = window.getSelection()
        sel.removeAllRanges()
        sel.addRange range
      else if document.body.createTextRange?
        textRange = document.body.createTextRange()
        textRange.moveToElementText el
        textRange.collapse false
        textRange.select()

      $(@)


    SelectElementContents: (opts) ->
      select = (elem) ->
        if $(elem).get(0).nodeName.toLowerCase() in [ 'input', 'textarea' ]
          $(elem).select()
        else if window.getSelection && document.createRange
          range = document.createRange()
          range.selectNodeContents $(elem).get(0)
          sel = window.getSelection()
          sel.removeAllRanges()
          sel.addRange range
        else if document.body.createTextRange
          range = document.body.createTextRange()
          range.moveToElementText $(elem).get(0)
          range.select()

      delay = if opts?.delay then parseInt opts?.delay else 1
      if delay
        setTimeout =>
          select @
        , delay
      else
        select @


    IsVisibleWithinParent: (opts) ->
      $child = $(@)
      $parent = $(@).parent()

      pScrollTop = $parent.scrollTop()
      pScrollBottom = pScrollTop + $parent.outerHeight()
      cTop = $child.position().top + parseInt($child.css('margin-top') || 0) +
        pScrollTop
      cBottom = cTop + $child.height()

      topMatch = pScrollTop <= cTop <= pScrollBottom
      bottomMatch = pScrollTop <= cBottom <= pScrollBottom

      topMatch && (!opts?.strict || bottomMatch)


    AnimateTo: (opts = {}) ->
      $elem = $(@)

      if $elem.get(0) && opts.to?
        $clone = $elem.clone().appendTo('body')

        fontSize = parseInt $elem.css('font-size')
        $clone.css
          'position'  : 'absolute'
          'font-size' : fontSize + 'px'
          'top'       : $elem.offset().top
          'left'      : $elem.offset().left

        $tgt = $(opts.to)
        tgtPos =
          h : $tgt.show().height()
          w : $tgt.width()
          t : $tgt.offset().top
          l : $tgt.offset().left
        $tgt.hide()

        paddingTop = (tgtPos.h - fontSize) / 2
        paddingLeft = (tgtPos.w - fontSize) / 2

        $clone.animate
          top  : tgtPos.t + paddingTop
          left : tgtPos.l + paddingLeft
        , 400, 'swing', ->
          $(@).remove()
          opts.onDone?.call @

      $(@)


    HtmlWrapUrl: (opts = {}) ->
      c_class = (c) -> '[\\w\\' + c.split('').join('\\') + ']'
      wrap_span = (str) ->
        '<span class="' + prefix + '-wrap-url" contenteditable="false">' + str +
          '</span>'

      base_chars = "-~/#[]@$&'*+,;="

      cend = c_class base_chars
      c = c_class base_chars + ':!?'

      re_prot = "https?:\\/\\/#{c}+((\\.#{c}*#{cend})+|#{cend})"
      re_noprot = "#{c}+(\\.#{c}*#{cend})+"

      re = new RegExp "(#{re_prot}|#{re_noprot})", 'gi'

      @each ->
        $(@).find('*').addBack().contents().filter( -> @nodeType == 3 ).each ->
          str = @nodeValue
          if str.match re
            str = str.replace(/</g, ' &lt; ').replace(/>/g, ' &gt; ')
              .replace(re, (word) ->
                # youtube url -> iframe embedding
                if opts.youtube && (videoinfo = utils.parseVideoUrl word) &&
                    videoinfo.type is 'youtube'
                  return utils.videoIframe videoinfo.id

                # vimeo url -> iframe embedding
                if opts.vimeo && (videoinfo = utils.parseVideoUrl word) &&
                    videoinfo.type is 'vimeo'
                  return utils.videoIframe videoinfo.id, type: videoinfo.type

                # check host format when no protocol given
                if !word.match /^http/
                  host = word.match(/^[^\/]+/)?[0] || ''
                  if !host.match(/^\d{1,3}(\.\d{1,3}){3}$/) &&
                      !host.match(/[a-z]{2,6}(:\d+)?$/i)
                    return word

                href = word
                href = 'http://' + href unless href.match /^http/
                wrap_span '<a class="' + prefix + '-link" href="' + href +
                  '" target="_blank">' + word + '</a>'

              ).replace /\s?(&lt;|&gt;)\s?/g, '$1'

            $(@).replaceWith str

    HtmlUnWrapUrl: (opts = {}) ->
      @each ->
        rpl = []

        $(@).find(".#{prefix}-wrap-url").each ->
          $a = $(@).find('a')
          lnk = $a.html() || ''
          rpl.push [ lnk, $(@) ]

        $(@).find('iframe').each ->
          src = $(@).attr 'src'
          type = if opts.youtube && src?.match /youtube.+embed\/(.+)$/
            'youtube'
          else if opts.vimeo && src?.match /vimeo\.com\/video\/(.+)$/
            'vimeo'
          if type
            src = utils.videoUrl RegExp.$1, type: type
            rpl.push [ src, $(@) ]

        r[1].replaceWith r[0] for r in rpl

    MainScrollCont: ->
      if utils.browser('firefox') then $('html') else $('body')

    # TODO: handle when container is smaller than item
    ScrollToMe: (opts = {}) ->
      offtop = $(@)[0].offsetTop

      if opts.container
        $cont = $(@).closest(opts.container)

        $offel = $(@).offsetParent()
        while $offel[0] isnt $cont[0] && $offel.closest($cont)[0]
          offtop += $offel[0].offsetTop
          border = parseInt $offel.css 'border-top-width'
          offtop += border unless isNaN border
          $offel = $offel.offsetParent()
      else
        $cont = $(@).parent()

      $scrollcont = if $cont[0] is $('body')[0]
        $[prefix + 'MainScrollCont']()
      else
        $cont

      cont_sctop = $scrollcont.scrollTop()
      cont_h = opts.containerHeight ? $cont.height()
      h = $(@).outerHeight()
      offtop -= opts.shift if opts.shift
      padding = opts.padding ? 0

      dst = if !opts.top && cont_h >= h
        # top cover
        if offtop - cont_sctop < 0
          offtop - padding
        # bottom cover
        else if offtop - cont_sctop + h > cont_h
          offtop - cont_h + h + padding
      else if opts.top
        offtop - padding

      if dst?
        $scrollcont.animate scrollTop: dst,
          $.extend duration: 200, opts.animationOpts

      $(@)


    HasOverflowWidth: ->
      border_width = parseInt($(@).css('border-left-width') ? 0) +
        parseInt($(@).css('border-right-width') ? 0)
      $(@)[0].scrollWidth > $(@)[0].offsetWidth - border_width


    Table2Array: ->
      data = []
      ranges = []
      r = 0

      @each ->
        $(@).find('tr').each (i, tr) ->
          row = []

          $(tr).find('th, td').each (j, td) ->
            $td = $(td)
            cs = parseInt($td.attr 'colspan') || 1
            rs = parseInt($td.attr 'rowspan') || 1
            val = $td.text().trim()

            ranges.forEach (range) ->
              if range.s.r <= r <= range.e.r &&
                  range.s.c <= row.length <= range.e.c &&
                  range.e.c >= range.s.c
                row.push null for [ 0 .. range.e.c - range.s.c ]

            if rs > 1 || cs > 1
              ranges.push
                s : r: r, c: row.length
                e : r: r + rs - 1, c: row.length + cs - 1

            row.push if val != '' then val else null

            row.push null for [ 0 .. cs - 2 ] if cs > 1

          data.push row
          r++

      [ data, ranges ]

  $.fn[prefix + name] = func for name, func in fns

  # ---- Class based plugins --------------------------------------------------

  # ---- Plugin register helpers ----------------------------------------------

  $["_#{prefix}CreatePlugin"] = (cname, klass, pname) ->
    (opts) ->
      args = Array.prototype.slice.call arguments, 1
      @each ->
        obj = $(@).data pname

        if typeof(opts) is 'string'
          $.error "Cannot call #{opts}, #{pname} is not present" unless obj
          obj[opts].apply obj, args

          if opts is 'destroy'
            for elem in [ '$el', 'el', 'opts', 'pluginName', 'className' ]
              delete obj[elem]
            $(@).data pname, null

        else if !obj
          $(@).data pname, new klass @, cname, opts

  $["_#{prefix}RegisterPlugins"] = (pluginobj) ->
    for name, val of pluginobj
      plugin_name = "#{prefix}#{name}"
      $.fn[plugin_name] = $["_#{prefix}CreatePlugin"] name, val, plugin_name

  # ---- PluginBase -----------------------------------------------------------

  $["_#{prefix}PluginBase"] = class PluginBase
    constructor: (@el, @className, opts) ->
      @$el = $(@el)
      @pluginName = "#{prefix}#{@className}"
      @opts = $.extend {}, @defaults, opts
      @init()

    init: -> # should be overridden

  plugins = {}

  # ---- Checkbox -------------------------------------------------------------

  class plugins.Checkbox extends PluginBase
    defaults:
      'contClass'     : "#{prefix}-checkbox"
      'markTemplate'  : '<div><i class="fa fa-check"></i></div>'
      'markClass'     : "#{prefix}-checkmark"
      'checkedClass'  : "#{prefix}-checked"
      'disabledClass' : "#{prefix}-disabled"

    init: ->
      if @$el.parent()[0].nodeName.toLowerCase() isnt 'label'
        @$el.wrap('<div>')
      else
        @labeled = true

      @$el.hide()
      @$cont = @$el.parent().addClass @opts.contClass
      @$chk = $(@opts.markTemplate).addClass(@opts.markClass).prependTo @$cont
      @adjustChecked()

      @disable() if @$el.is ':disabled'

      @$cont.on 'click', @click unless @labeled
      @$el.on 'change', @adjustChecked

    click: =>
      return if @$cont.hasClass @opts.disabledClass
      @$el.prop('checked', !@$el.prop('checked')).trigger 'change'

    adjustChecked: =>
      @$cont.toggleClass @opts.checkedClass, @$el.prop('checked')

    enable: =>
      @$cont.removeClass @opts.disabledClass
      @$el.removeAttr 'disabled'

    disable: =>
      @$cont.addClass @opts.disabledClass
      @$el.prop 'disabled', true

    destroy: =>
      @$cont.off 'click', @click unless @labeled
      @$el.off 'change', @adjustChecked

      @$cont.find(".#{@opts.markClass}").remove()

      if @labeled
        @$cont.removeClass @opts.contClass
      else
        @$el.unwrap()

      @$el.show()

      delete @[elem] for elem in [ '$cont', '$chk', 'labeled' ]

  # ---- Radio ----------------------------------------------------------------

  class plugins.Radio extends plugins.Checkbox
    defaults:
      'contClass'     : "#{prefix}-radio"
      'markTemplate'  : '<div><i></i></div>'
      'markClass'     : "#{prefix}-checkmark"
      'checkedClass'  : "#{prefix}-checked"
      'disabledClass' : "#{prefix}-disabled"

    click: =>
      return if @$cont.hasClass @opts.disabledClass
      @$el.prop 'checked', true

    adjustChecked: (e) =>
      super
      if e
        $('input:radio[name=' + @$el.attr('name') + ']').not(@$el)
          .closest(".#{@opts.contClass}").removeClass @opts.checkedClass

  # ---- Dropdown -------------------------------------------------------------

  class plugins.Dropdown extends PluginBase
    defaults:
      'contClass'  : "#{prefix}-dd-cont"
      'boxClass'   : "#{prefix}-dd"
      'optsClass'  : "#{prefix}-dd-opts"
      'selClass'   : "#{prefix}-selected"
      'hoverClass' : "#{prefix}-itemhover"
      'tabindex'   : 0

    init: ->
      @$el.wrap('<div>').hide()
      $cont = @$el.parent().addClass @opts.contClass

      @$box = $('<div>').addClass(@opts.boxClass)
        .attr('tabindex', @opts.tabindex).appendTo $cont
      @$options = $('<div>').addClass(@opts.optsClass).appendTo $cont

      $ul = $('<ul>')
      @$el.find('option').each (i, el) ->
        $el = $(el)
        $('<li>').html($el.text()).attr('data-value', $el.attr 'value')
          .appendTo $ul

      @$options.append $ul

      # event handlers
      @opts.btn?.click @clickBox
      if !@opts.btn || !@$box.closest(@opts.btn)[0]
        @$box.click @clickBox
      @$box.keydown @keydownBox
      @$options.on 'mouseover', 'li', @hoverOption
      @$options.on 'click', 'li', @clickOption
      $(document).on 'click', @clickDoc

      @setValue @$el.val()

    clickDoc: (e) =>
      $tgt = $(e.target)
      if !$tgt.closest(@$el.parent())[0] &&
          !$tgt.closest(@opts.btn)[0]
        @toggleOptions false

    clickOption: (e) =>
      e.stopPropagation()
      @setValue $(e.target)
      @$box.focus()

    clickBox: =>
      @toggleOptions()
      @$box.focus()

    keydownBox: (e) =>
      key = e.which
      # key codes: ENTER: 13, ESC: 27, UP: 38, DOWN: 40
      if key in [ 13, 27, 38, 40 ]
        if key == 27
          @toggleOptions false
        else if @$options.is ':visible'
          if key in [ 38, 40 ]
            $hover = @$options.find '.' + @opts.hoverClass
            $sibling = $hover[ if key == 38 then 'prev' else 'next' ]()

            if $sibling[0]
              $hover.removeClass @opts.hoverClass
              $sibling.addClass @opts.hoverClass
          else
            @setValue @$options.find '.' + @opts.hoverClass
        else
          @toggleOptions true

        false

    toggleOptions: (show) =>
      func = if show?
        if show then 'Down' else 'Up'
      else
        'Toggle'

      @$options['slide' + func](100, =>
        @$options.find('li').removeClass(@opts.hoverClass)
          .filter('.' + @opts.selClass).addClass @opts.hoverClass
        @$el.trigger 'toggle', @$options
      )

    hoverOption: (e) =>
      $(e.target).addClass(@opts.hoverClass).siblings()
        .removeClass @opts.hoverClass

    setValue: (val) =>
      return unless val?
      $items = @$options.find('li')

      if typeof(val) is 'object'
        $selitem = $(val)
      else
        $items.each (i, el) ->
          if $(el).data('value')?.toString() is val.toString()
            $selitem = $(el)
            return

      if $selitem
        $curritem = $items.filter '.' + @opts.selClass

        if $selitem[0] isnt $curritem[0]
          $items.removeClass @opts.selClass
          $selitem.addClass @opts.selClass
          @$box.text $selitem.text()
          val = $selitem.data('value')?.toString()
          @$el.val(val).trigger 'change' unless val is @$el.val()

        @toggleOptions false

    destroy: =>
      $(document).off 'click', @clickDoc
      @opts.btn?.off 'click', @clickBox

      @$el.parent().find('.' + @opts.optsClass + ', .' + @opts.boxClass)
        .remove()

      @$el.unwrap().show()

      delete @[elem] for elem in [ '$options', '$box' ]

  # ---- Menu -----------------------------------------------------------------
  # TODO: more options & consider merging with Dropdown

  class plugins.Menu extends PluginBase
    defaults:
      appendTo       : 'body'
      menuClass      : "#{prefix}-dd-opts"
      itemClass      : "#{prefix}-dd-item"
      separatorClass : "#{prefix}-dd-separator"
      labelClass     : "#{prefix}-dd-label"
      align          : 'left'

    init: ->
      @$menu = if @opts.items instanceof jQuery
        @opts.items
      else
        $items = $('<ul>')

        (@opts.items || []).forEach (item, idx) =>
          $item = $('<li>')

          text = utils.encodeHtml if $.isPlainObject item
            id = item.id if item.id
            if item.separator || item.label
              $item.addClass @opts.separatorClass if item.separator
              $item.addClass @opts.labelClass if item.label
            else
              active = true
            item.text
          else
            active = true
            item

          if active
            $item.addClass(@opts.itemClass).append $('<a>').html text
          else
            $item.html text

          $item.attr 'data-id', id if id
          $items.append $item

        $('<div>').append $items

      @$menu.addClass(@opts.menuClass).hide().on \
        'click', ".#{@opts.itemClass}", @clickItem
      @$menu.appendTo $(@opts.appendTo) if @opts.appendTo

      @$el.click @toggleMenu
      $(document).on 'click', @clickDoc

    toggleMenu: =>
      if @$menu.is ':visible' then @hideMenu() else @showMenu()

    showMenu: =>
      return if @$menu.is ':visible'

      offset = @$el.offset()
      left = offset.left

      if @opts.align isnt 'left'
        diff = @$el.outerWidth() - @$menu.outerWidth()
        left += if @opts.align is 'center'
          parseInt diff / 2
        else
          diff

      elHeight = @$el.outerHeight()
      menuHeight = @$menu.outerHeight()
      windowHeight = $(window).height()
      top = offset.top - $(document).scrollTop() + elHeight

      if top + menuHeight > windowHeight && offset.top > windowHeight - top
        top -= menuHeight + elHeight + 2 * parseInt @$menu.css 'margin-top'

      @$el.trigger 'showmenu', @$menu

      @$menu.css(top: top, left: left).fadeIn 'fast'

    hideMenu: =>
      return unless @$menu.is ':visible'
      @$menu.fadeOut 'fast'

    toggleItems: (ids, bool) =>
      ids = [ ids ] unless $.isArray ids
      @$menu.find(".#{@opts.itemClass}").each (idx, el) ->
        id = $(el).data 'id'
        $(el).toggle if bool then id in ids else id not in ids

    clickItem: (e) =>
      $item = $(e.target).closest('li')
      @$el.trigger 'clickitem', $item.data('id') || $item.index @opts.itemClass

    clickDoc: (e) =>
      @hideMenu() unless $(e.target).closest(@$el)[0]

    destroy: ->
      @$el.off 'click', @showMenu
      $(document).off 'click', @clickDoc
      @$menu.remove()
      delete @$menu

  # ---- DatePicker -----------------------------------------------------------

  # TODO: moment dependency!
  class plugins.DatePicker extends PluginBase
    defaults:
      openClass   : "#{prefix}-k-open"
      closeButton : false
      direction   : 'today-past'

    init: ->
      @opts.parser ?= moment
      @opts.getNow ?= moment
      @$btn = @opts.inputBtn

      # events
      if @$btn
        for ev in [ 'mousedown', 'click' ]
          @$btn.on ev, @[ev + 'Btn']

      for ev in [ 'click', 'focus', 'blur', 'change', 'keydown' ]
        @$el.on ev, @[ev + 'Input']

      @$el.kalendae @opts

    mousedownBtn: (e) =>
      kal = @$el.data('kalendae')?.container
      @$btn.toggleClass @opts.openClass, kal && $(kal).is ':visible'

    clickBtn: (e) =>
      if @$btn.hasClass @opts.openClass
        @$btn.removeClass @opts.openClass
      else
        @$el.click()

    focusInput: (e) =>
      @initDate = @opts.parser @$el.val() || @opts.getNow()
      @result = undefined

    blurInput: (e) =>
      if @hasOwnProperty 'result'
        val = @result
        delete @result
        @$el.trigger 'pickdone', val

    clickInput: (e) =>
      @$el.select()

    changeInput: (e) =>
      val = @$el.val().trim().toLowerCase()
      val = 'today' if @opts.todayStr && val is @opts.todayStr.toLowerCase()
      dm = @opts.parser val

      if typeof dm is 'object' && dm.isValid && dm.isValid()
        @result = @$el.val()
      else
        dm = @initDate

      @$el.val moment(dm).format @opts.format
      @$el.blur()

    keydownInput: (e) =>
      act = switch e.keyCode
        when 27 then @$el.val(@initDate.format @opts.format).blur()
        when 13 then @$el.trigger 'change'
      e.preventDefault() if act

    destroy: ->
      if @$btn
        for ev in [ 'mousedown', 'click' ]
          @$btn.off ev, @[ev + 'Btn']

      for ev in [ 'click', 'focus', 'blur', 'change', 'keydown' ]
        @$el.off ev, @[ev + 'Input']

      @$el.data('kalendae')?.destroy()

      for elem in [ '$btn', 'initDate', 'result' ]
        delete @[elem]

  # ---- ContentSpy -----------------------------------------------------------

  class plugins.ContentSpy extends PluginBase
    defaults:
      delay      : 200
      ignoreCase : true

    init: ->
      if @el.nodeName.toLowerCase() in [ 'input', 'textarea' ]
        @$el.on ev, @[ev + 'Input'] for ev in [ 'focus', 'blur', 'keydown' ]
      else if @$el.attr 'contenteditable'
        @conted = true
        if window.MutationObserver
          @observer = new MutationObserver @subtreeModified
          @observer.observe @el,
            childList     : true
            subtree       : true
            characterData : true
        else
          @$el.on 'DOMSubtreeModified', @subtreeModified

    subtreeModified: =>
      clearTimeout @_subtree_change_timer
      @_subtree_change_timer = setTimeout =>
        @$el.trigger 'contentchange', [ @$el.text() ]
      , @opts.delay

    focusInput: (e) =>
      @initVal = @$el.val()
      @startInspect focus: true

    blurInput: (e) =>
      @stopInspect()

    keydownInput: (e) =>
      @stopInspect()
      @nextInspect()

    startInspect: (opts) =>
      return if opts?.focus && @_inspect_timer
      @stopInspect()
      currVal = @$el.val()

      if @opts.ignoreSelection # works only for text inputs / textareas
        start = @el.selectionStart || 0
        end = @el.selectionEnd || 0
        if start < end
          currVal = currVal.substr(0, start) + currVal.substr(end)

      if currVal.toLowerCase() isnt @initVal.toLowerCase() ||
          !@opts.ignoreCase && currVal isnt @initVal
        prevVal = @initVal
        @initVal = currVal
        @$el.trigger 'contentchange', [ currVal, prevVal ]

      @nextInspect()

    nextInspect: =>
      @_inspect_timer = setTimeout @startInspect, @opts.delay

    stopInspect: =>
      clearTimeout @_inspect_timer
      delete @_inspect_timer

    destroy: =>
      if @conted
        if @observer
          @observer.disconnect()
          delete @observer
        else
          @$el.off 'DOMSubtreeModified', @subtreeModified

        clearTimeout @_subtree_change_timer
        delete @[prop] for prop in [ 'conted', '_subtree_change_timer' ]
      else
        @stopInspect()
        @$el.off ev, @[ev + 'Input'] for ev in [ 'focus', 'blur', 'keydown' ]
        delete @initVal

  # ---- AutoSuggest ----------------------------------------------------------

  class plugins.AutoSuggest extends PluginBase
    defaults:
      appendTo        : 'body'
      inputClass      : "#{prefix}-as-input"
      listTemplate    : '<ul></ul>'
      listClass       : "#{prefix}-as-list"
      itemTemplate    : '<li><i></i><span></span></li>'
      itemClass       : "#{prefix}-as-item"
      itemHoverClass  : "#{prefix}-as-item-hover"
      itemSelClass    : "#{prefix}-as-item-sel"
      itemSearchClass : "#{prefix}-as-item-search"
      itemLimit       : 10
      iconOnlySearch  : true

    init: ->
      if !$.isFunction(@opts.source) && !$.isArray(@opts.source)
        @opts.source = []

      @$el["#{prefix}ContentSpy"]().addClass(@opts.inputClass)
        .on('contentchange', @processText)
        .on('blur', @blurInput)
        .on('keydown', @keydownInput)

    getVal: => @$el["#{prefix}InputVal"]().trim()

    fillInput: (text, opts) =>
      @select = true if opts?.select
      @$el["#{prefix}InputVal"](text)["#{prefix}SetCaretToEnd"]()

    processText: (e) =>
      return unless document.activeElement is @el

      if @select
        delete @select
        return

      val = @getVal()
      if val
        @searchItems(val).done (items) =>
          return unless @$el && @getVal() is val
          items ?= []
          if items.length
            for item, i in items
              if item.toLowerCase() is val.toLowerCase()
                idx = i
                break

            items.splice idx, 1 if idx
            items.unshift val if !idx? || idx

          @buildItems items
      else
        @hideItems()

    searchItems: (txt) =>
      if $.isFunction @opts.source
        @opts.source txt
      else
        $.Deferred().resolve \
          $.grep @opts.source, (n, i) -> utils.startMatch n, txt

    buildItems: (items) =>
      if !items?.length
        @hideItems()
        return

      itemSelector = ".#{@opts.itemClass}"

      if @$listEl
        @$listEl.detach()
      else
        @$listEl = $(@opts.listTemplate).addClass(@opts.listClass)
          .on 'mousedown', itemSelector, (e) =>
            @fillInput $(e.target).closest(itemSelector).data 'descr'
            @hideItems()
            @$el.trigger 'clickitem'

      @$listEl.css width: @$el.outerWidth() if @opts.autoWidth

      if $.isPlainObject @opts.listClassByParent
        for p, c of @opts.listClassByParent
          @$listEl.addClass c if p && c && @$el.closest(p).get(0)

      $itemCont = if @opts.itemCont
        @$listEl.find(@opts.itemCont)
      else
        @$listEl

      $itemCont.empty()

      for item, i in items
        break if i > @opts.itemLimit - 1
        $item = $(@opts.itemTemplate).addClass(@opts.itemClass).data 'descr', item
        $item.addClass @opts.itemSelClass + ' ' + @opts.itemSearchClass unless i
        if @opts.iconClass && (!@opts.iconOnlySearch || !i)
          $item.find('i').addClass @opts.iconClass
        else
          $item.find('i').hide()
        $item.find('span').html utils.encodeHtml item
        $itemCont.append $item

      ih = @$el.outerHeight()
      top = @$el.offset().top + ih + 1
      left = @$el.offset().left

      appendEl = if @opts.appendTo in [ 'parent', 'offsetParent' ]
        @$el[@opts.appendTo]()
      else
        @opts.appendTo

      # TODO: support body as object if needed
      if @opts.appendTo isnt 'body'
        top -= $(appendEl).offset().top
        left -= $(appendEl).offset().left

      @$listEl.appendTo(appendEl).show().css top: top, left: left

      # browser window outreach correction
      if @opts.appendTo is 'body'
        ww = $(window).width()
        lw = @$listEl.outerWidth()
        @$listEl.css left: ww - lw if ww < left + lw

        lh = @$listEl.outerHeight()
        if top + lh > $(window).height() + $(document).scrollTop() &&
            (uptop = top - lh - ih - 2) > 0
          @$listEl.find(".#{@opts.itemSearchClass}").appendTo @$listEl
          @$listEl.css top: uptop

      @$el.trigger 'suggest', @$listEl

    hideItems: =>
      @$listEl?.hide()

    destroyItems: =>
      @$listEl?.remove()
      delete @$listEl

    keydownInput: (e) =>
      return unless @$listEl?.is(':visible') && e.which in [ 13, 27, 38, 40 ]

      # key codes: ENTER: 13, ESC: 27, UP: 38, DOWN: 40
      if e.which == 13
        @hideItems()
        delete @select
      else
        e.preventDefault()

        $sel = @$listEl.find ".#{@opts.itemSelClass}"

        $sib = if e.which == 27
          @$listEl.find ".#{@opts.itemSearchClass}"
        else if e.which == 38
          if $sel
            $sel.prev()
          else
            @$listEl.find ".#{@opts.itemClass}:first"
        else if $sel
          $sel.next()
        else
          @$listEl.find @opts.itemClass + ':last'

        if e.which == 27 && $sib[0] && $sel[0] && $sib[0] is $sel[0]
          @hideItems()
        else if $sib[0]
          $sel.removeClass @opts.itemSelClass
          $sib.addClass @opts.itemSelClass
          @fillInput $sib.data('descr'), select: true

    blurInput: (e) =>
      @destroyItems()

    destroy: =>
      @destroyItems()

      @$el["#{prefix}ContentSpy"]('destroy').off 'contentchange', @processText
      @$el.off ev, @[ev + 'Input'] for ev in [ 'keydown', 'blur' ]

      delete @select

  # ---- Modal ----------------------------------------------------------------

  class plugins.Modal extends PluginBase
    defaults:
      'modalClass'     : "#{prefix}-modal"
      'modalShowClass' : "#{prefix}-modal-show"
      'bgClass'        : "#{prefix}-modal-bg"
      'bgFadeTime'     : 200
      'transitionTime' : 200

    init: ->
      @$el.addClass(@opts.modalClass).appendTo 'body'
      @show() if @opts.show

    triggerBgClick: =>
      @$el.trigger 'bgclickmodal'

    show: =>
      return if @$el.hasClass @opts.modalShowClass

      @$bg = $('<div>').addClass(@opts.bgClass).appendTo('body')
        .fadeIn @opts.bgFadeTime, =>
          @$el.addClass @opts.modalShowClass
          @_showTimer = setTimeout =>
            $('body').addClass @opts.bodyShowClass if @opts.bodyShowClass
            @$el.trigger 'showmodal'
            @$bg.on 'click', @triggerBgClick
          , @opts.transitionTime

    hide: (opts) =>
      clearTimeout @_showTimer
      return unless @$el.hasClass @opts.modalShowClass

      @$el.removeClass @opts.modalShowClass

      _removeBg = =>
        @$bg?.off 'click', @triggerBgClick
        @$bg?.remove()
        delete @$bg
        $('body').removeClass @opts.bodyShowClass if @opts.bodyShowClass
        @$el.trigger 'hidemodal'

      if opts?.destroy || !@$bg
        _removeBg()
      else
        @$bg.fadeOut @opts.bgFadeTime, _removeBg

    destroy: =>
      @hide destroy: true
      delete @_showTimer
      @$el.removeClass(@opts.modalClass).detach()

  # ---- Tabs -----------------------------------------------------------------

  class plugins.Tabs extends PluginBase
    defaults:
      'contSelector'       : ".#{prefix}-tabs"
      'tabSelector'        : ".#{prefix}-tab"
      'activeClass'        : "#{prefix}-active"
      'leftArrowSelector'  : ".#{prefix}-btn-left"
      'rightArrowSelector' : ".#{prefix}-btn-right"
      'scrollDelay'        : 200

    init: ->
      @$cont = @$el.find @opts.contSelector
      @$tabs = @$cont.find @opts.tabSelector
      @$leftArrow = @$el.find @opts.leftArrowSelector
      @$rightArrow = @$el.find @opts.rightArrowSelector

      @adjustArrows()

      @$tabs.click @clickTab
      @$leftArrow.click @scrollLeft
      @$rightArrow.click @scrollRight

    adjustArrows: =>
      scrollLeft = @$cont.scrollLeft()
      @$leftArrow.toggle scrollLeft > 0
      @$rightArrow.toggle \
        @$tabs.last()[0]?.offsetLeft >= scrollLeft + @$cont.width()

    scroll: (dst) =>
      return unless @$el.is ':visible'
      scrollPos = null

      if dst in [ 'left', 'right' ]
        @$tabs.each (i, el) =>
          offset = @scrollOffset el, dst
          if offset?
            scrollPos = offset
            false if dst is 'right'
      else if $(dst)[0]
        scrollPos = @scrollOffset dst

      if scrollPos?
        if @opts.scrollDelay
          @$cont.animate scrollLeft: scrollPos, @opts.scrollDelay, @adjustArrows
        else
          @$cont.scrollLeft scrollPos
          @adjustArrows()

    scrollOffset: (tab, dir) =>
      $tab = $(tab)
      if $tab[0]
        if (!dir || dir is 'left') && $tab.position().left < 0
          $tab[0].offsetLeft
        else if !dir || dir is 'right'
          rightEdge = $tab[0].offsetLeft + $tab.outerWidth()
          contWidth = @$cont.width()
          rightEdge - contWidth if rightEdge > @$cont.scrollLeft() + contWidth

    scrollLeft: => @scroll 'left'

    scrollRight: => @scroll 'right'

    clickTab: (e) =>
      @activate $(e.target).closest @opts.tabSelector

    activate: (tab) =>
      $tab = if typeof tab is 'object'
        $(tab)
      else if typeof tab is 'number'
        @$tabs.eq parseInt tab
      else
        @$tabs.filter tab

      if $tab
        @$tabs.not($tab).removeClass @opts.activeClass
        if !$tab.hasClass @opts.activeClass
          $tab.addClass(@opts.activeClass).trigger 'tabactivate'
        @scroll $tab

    destroy: =>
      @$tabs.off 'click', @clickTab
      @$leftArrow.off 'click', @scrollLeft
      @$rightArrow.off 'click', @scrollRight

      delete @[prop] for prop in [ '$cont', '$tabs', '$leftArrow',
                                   '$rightArrow' ]

  # ---- AutoScroll -----------------------------------------------------------

  class plugins.AutoScroll extends PluginBase
    defaults:
      border    : '20%'
      borderMax : 100
      speed     : 500 # px / sec
      expansion : false
      horiz     : false

    init: ->
      for action in [ 'start', 'stop' ]
        @$el.on "#{action}autoscroll", @[action]

      for dir in [ 'begin', 'end' ]
        marker = "#{dir}Marker"
        if @opts[marker]
          @['$' + marker] = if @opts[marker] instanceof jQuery
            @opts[marker]
          else
            @$el.find @opts[marker]

      @adjustMarkers()

      @$el.on 'scrollstop', @adjustMarkers

      @start() if @opts.start

    start: =>
      return if @_started
      @stop()
      @_started = true
      $('body').on 'mousemove', @mouseMove

    stop: =>
      @_stop()
      delete @_scrollSize
      delete @_started
      $('body').off 'mousemove', @mouseMove

    _stop: =>
      if @$el.is ':animated'
        @$el.stop()
        @$el.trigger 'scrollstop'

    adjustMarkers: =>
      if @$beginMarker || @$endMarker
        scrollPos = @scrollPos()
        scrollSize = @scrollSize()
        contSize = @contSize()

        if @$beginMarker
          @$beginMarker.toggle !!(scrollPos > 0 && scrollSize > contSize)

        if @$endMarker
          @$endMarker.toggle !!(scrollPos + contSize < scrollSize)

    pos: (pos) =>
      @$el[ if @opts.horiz then 'scrollLeft' else 'scrollTop' ](pos)
      @adjustMarkers()

    posBegin: =>
      @pos 0

    posEnd: =>
      @pos @scrollSize()

    scrollPos: =>
      if @opts.horiz then @$el.scrollLeft() else @$el.scrollTop()

    scrollSize: =>
      if @opts.horiz then @el.scrollWidth else @el.scrollHeight

    contSize: =>
      if @opts.horiz then @$el.width() else @$el.height()

    mouseMove: (e) =>
      return unless @$el.is ':visible'
      offset = @$el.offset()
      w = @$el.outerWidth()
      h = @$el.outerHeight()
      x = e.pageX - offset.left
      y = e.pageY - offset.top

      if @opts.horiz
        size = pri: w, sec: h
        pos = pri: x, sec: y
      else
        size = pri: h, sec: w
        pos = pri: y, sec: x

      border = if @opts.border.match /\%$/
        size.pri * parseInt(@opts.border) / 100
      else
        @opts.border
      border = @opts.borderMax if @opts.borderMax? && border > @opts.borderMax

      scrollSize = if @opts.expansion || !@_scrollSize
        @scrollSize()
      else
        @_scrollSize

      @_scrollSize = scrollSize unless @_scrollSize || @opts.expansion

      scrollPos = @scrollPos()

      if 0 <= pos.sec <= size.sec
        scrollSide = if 0 <= pos.pri <= border
          0
        else if size.pri - border <= pos.pri <= size.pri &&
            scrollPos + @contSize() < scrollSize
          scrollSize

      if scrollSide?
        diff = scrollPos - scrollSide
        if !@$el.is(':animated') && diff
          @$el.trigger 'scrollstart'
          (aopts = {})[ if @opts.horiz then 'scrollLeft' else 'scrollTop' ] =
            scrollSide

          @$el.animate aopts, parseInt(Math.abs(diff) / @opts.speed * 1000),
            => @$el.trigger 'scrollstop'
      else
        @_stop()

    destroy: =>
      for action in [ 'start', 'stop' ]
        @$el.off "#{action}autoscroll", @[action]
      @$el.off 'scrollstop', @adjustMarkers
      delete @["$#{dir}Marker"] for dir in [ 'begin', 'end' ]
      @stop()

  # ---- DragSpy --------------------------------------------------------------

  class plugins.DragSpy extends PluginBase
    defaults:
      directionX     : 'ltr' # ltr / rtl
      directionY     : 'ttb' # ttb / btt
      moveClass      : "#{prefix}-dragging"
      distance       : 10
      longPressDelay : 500

    init: ->
      # TODO: detect touch capability?
      @touch = utils.isMobile()

      if @touch
        @$el
          .on 'touchstart', @touchstart
          .on 'touchend', @touchend
      else
        @$el.on 'mousedown', @start

      $(document).on 'mousemove touchmove', @move

    eventPos: (e) =>
      oe = e.originalEvent

      x : oe.pageX ? oe.changedTouches[0].pageX
      y : oe.pageY ? oe.changedTouches[0].pageY

    touchstart: (e) =>
      @_touchTimer = setTimeout =>
        @start e
      , @opts.longPressDelay

    touchend: =>
      clearTimeout @_touchTimer
      delete @_touchTimer

    start: (e) =>
      @params = @eventPos e

      $(document)
        .on 'mouseup touchend', @end
        .find('html').addClass @opts.moveClass

      @opts.onStart $.extend $el: @$el, @params if @opts.onStart

    move: (e) =>
      if !@params
        @touchend()
      else if @opts.onMove
        pos = @eventPos e

        params =
          dx  : pos.x - @params.x
          dy  : pos.y - @params.y
          $el : @$el

        if @touch ||
            (!@dragged &&
             (Math.abs(params.dx) >= @opts.distance ||
              Math.abs(params.dy) >= @opts.distance))
          @dragged = true

          if !@touch
            @params = pos
            params.dx = 0
            params.dy = 0

        if @dragged
          e.preventDefault()

          params.dx *= -1 if @opts.directionX is 'rtl'
          params.dy *= -1 if @opts.directionY is 'btt'

          @opts.onMove params

    end: =>
      $(document)
        .off 'mouseup touchend', @end
        .find('html').removeClass @opts.moveClass
      @opts.onEnd $el: @$el, dragged: @dragged if @opts.onEnd
      delete @[prop] for prop in [ 'dragged', 'params' ]

    adjustPos: (params) =>
      if @params
        for c in [ 'x', 'y' ]
          @params[c] = p if (p = params[c])?
          @params[c] += dp if (dp = params["d#{c}"])?

    destroy: =>
      @touchend()
      @end()
      @$el
        .off 'mousedown', @start
        .off ev, @[ev] for ev in [ 'touchstart', 'touchend' ]
      delete @touch

  # ---- Register class based plugins -----------------------------------------

  $["_#{prefix}RegisterPlugins"] plugins

)(jQuery)
