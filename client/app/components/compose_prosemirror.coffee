{ProseMirror} = require '../prosemirror/edit/index'
require '../prosemirror/menu/menubar'
{Schema, SchemaSpec, Text} = require '../prosemirror/model/schema'
{defaultSchema, Doc, Paragraph} = require "../prosemirror/model/defaultschema"
FileUtils = require '../utils/file_utils'
{Spinner} = require './basic_components'
{Image: PMImage} = require '../prosemirror/model/index'
{div} = React.DOM

module.exports = ProseMirrorComponent = React.createClass
    propTypes:
        options: React.PropTypes.object
        html: React.PropTypes.bool
        focus: React.PropTypes.bool
        signature: React.PropTypes.string
        onFiles: React.PropTypes.func
        valueLink: React.PropTypes.shape
            value: React.PropTypes.any.isRequired
            requestChange: React.PropTypes.func.isRequired

    render: ->
        div
            className: 'compose-content',
            ref: 'pmcontainer'
            onClick: @focusPM
            onDragOver  : @allowDrop
            onDragEnter : @onDragEnter
            onDragLeave : @onDragLeave
            onDrop      : @handleFiles
            onScroll    : @onScroll
            if @state.loadingImages
                Spinner()

    getInitialState: -> {}

    docFormat: ->
        if @props.html then 'html' else 'text'

    getSchema: ->
        if @props.html
            return defaultSchema

        else
            spec = new SchemaSpec
                doc: Doc
                paragraph: Paragraph
                text: Text
            , {}
            return new Schema spec


    focusPM: (event) ->
        if event.target.classList.contains 'ProseMirror'
            @pm.focus()

    onScroll: (event) ->
        @pm?.mod.menuBar.scrollFunc()

    componentWillUpdate: (props) ->
        if props.valueLink.value isnt @_lastValue
            @pm.setContent props.valueLink.value, props.options.docFormat

    componentWillMount: ->
        @_lastValue = @props.valueLink.value
        @waitingRead = 0
        options =
            doc: @_lastValue
            docFormat: @docFormat()
            schema: @getSchema()

        if @props.html
            options.menuBar = float: true

        @pm = new ProseMirror options

        # dont allow img creation
        if @props.html
            @pm.mod.menuBar.menuItems[0].pop()
            @pm.mod.menuBar.menuItems[0].splice 2, 1
            @pm.mod.menuBar.menuItems[1].pop()
            @pm.mod.menuBar.update.force()

    componentDidMount: ->
        @refs.pmcontainer.getDOMNode().appendChild @pm.wrapper
        @pm.on 'change', =>
            @_lastValue = @pm.getContent @docFormat()
            @props.valueLink.requestChange @_lastValue

        if @props.focus
            @pm.focus()


    # allow to drop items, toggle "target" state when droppable
    allowDrop: (e) -> e.preventDefault()
    onDragEnter: (e) -> @setState(target: true) if not @state.target
    onDragLeave: (e) -> @setState(target: false) if @state.target
    handleFiles: (e) ->
        e.preventDefault()
        domFiles = e.target.files or e.dataTransfer.files
        @setState(target: false)

        # Add all files to Compose file picker
        @props.onFiles domFiles
        waitingRead = 0

        if @props.html
            for file in domFiles
                if file.type.split('/')[0] is 'image'
                    @setState(loadingImages: true)
                    waitingRead++
                    do (file) => # use "do" create closure
                        FileUtils.fileToDataURI file, (dataURI) =>
                            waitingRead--
                            @onFileRead file, dataURI
                            if waitingRead is 0
                                @setState(loadingImages: false)



    onFileRead: (file, dataURI) ->

        img = @pm.schema.nodeType('image').create
            src: dataURI
            title: file.name
            alt: file.name

        @pm.apply @pm.tr.insert @pm.selection.from, img
