class Index extends App.ControllerSubContent
  requiredPermission: 'admin.text_module'
  header: 'TextModules'
  constructor: ->
    super

    new App.ControllerGenericIndex(
      el: @el
      id: @id
      genericObject: 'TextModule'
      pageData:
        home: 'text_modules'
        object: 'TextModule'
        objects: 'TextModules'
        navupdate: '#text_modules'
        notes: [
          'Text modules are ...'
        ]
        buttons: [
          { name: 'New text module', 'data-type': 'new', class: 'btn--success' }
        ]
      container: @el.closest('.content')
    )

App.Config.set('TextModule', { prio: 2300, name: 'TextModules', parent: '#manage', target: '#manage/text_modules', controller: Index, permission: ['admin.text_module'] }, 'NavBarAdmin')
