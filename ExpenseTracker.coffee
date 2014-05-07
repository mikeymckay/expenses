config = {
  local_database_name: "ExpenseTracker"
  remote_url: "https://couchapp:couchapp@expenses.couchappy.com/expenses"
}

clear = ->
  $("input").val("")
  $("[name=_id]").val new Date().toISOString().replace(/:(\d\d)\..*/, ".$1").replace(/T\d/," ")

fields = "Amount,Description,Category,_id,_rev".split(/,/)
$("#AddExpenses").prepend( _(fields).map (field) ->
  "
    <div style='display:block'>
    <label for='#{field}'>#{field}</label><br/>
    <input name='#{field}'></input>
    </div>
  "
.join("")
)
$("[for=_rev]").hide()
$("[name=_rev]").hide()
$("[name=Amount]").attr "type","number"
$("label[for=_id]").html "Time"
clear()

categories = []
descriptions = []

loadTable = ->

  categories = []
  descriptions = []

  db.query map: (doc) ->
      emit(doc.Amount) if doc.Amount
    ,
      include_docs: true
    , (error,result) ->
      $("#ExpenseList").html "
        <table id='expenses'>
          <thead>
            <tr>
              #{
              _(fields).map (field) ->
                return if field is "_rev"
                field = "Time" if field is "_id"
                "<th>#{field}</th>"
              .join("")
              }
              <th></th>
            </tr>
          </thead>
          <tbody>
            #{
            _(result.rows).map (row) ->
                
              categories.push row.doc.Category
              descriptions.push row.doc.Description
              "<tr>#{
                _(fields).map (field) ->
                  return if field is "_rev"
                  "<td class='loadOnClick #{field}'>#{row.doc[field]}</td>"
                .join("")
              }
                <td><button class='delete' data-rev='#{row.doc._rev}' data-id='#{row.doc._id}'>Delete</button></td>
              </tr>"
            .join("")
            }
          </tbody>
        </table>
      "
      $("#expenses").DataTable
        "order": [[ 3, "desc" ]]
      updateButtons()

updateButtons = ->
  $("#CategoryButtons").html( "Categories<br/>" + _(categories).chain().uniq().map (category) ->
    "<button data-type='Category'>#{category}</button><br/>"
  .value().join ""
  )
  $("#DescriptionButtons").html( "Descriptions<br/>" + _(descriptions).chain().uniq().map (description) ->
    "<button data-type='Description'>#{description}</button><br/>"
  .value().join ""
  )

db = new PouchDB(config.local_database_name)
loadTable()

$("#ExpenseList").on "click","button.delete", (event) ->
  buttonClicked = $(event.target)
  db.remove(buttonClicked.attr("data-id"), buttonClicked.attr("data-rev"))
  .then loadTable

$("#CategoryButtons,#DescriptionButtons").on "click","button", (event) ->
  buttonClicked = $(event.target)
  $("[name=#{buttonClicked.attr("data-type")}]").val buttonClicked.html()


$("#ExpenseList").on "click","td.loadOnClick", (event) ->
  id = $(event.target).closest("tr").find("._id").html()
  db.get id, (error,result) ->
    _(fields).each (field) ->
      $("[name=#{field}]").val result[field]

$("button#Clear").on "click", ->
  clear()

$("button#Save").on "click", ->
  doc = {}
  for field in fields
    doc[field] = $("[name=#{field}]").val()
  db.put doc, (error,response) ->
    console.log error
  .then loadTable
  .then clear


PouchDB.replicate config.local_database_name, config.remote_url,
  continuous: true
.on 'complete', (response) ->
  console.log JSON.stringify response
.on 'error', (error) ->
  console.log "ERROR on from replicate: #{JSON.stringify error}"

PouchDB.replicate config.remote_url, config.local_database_name,
  continuous: true
.on 'complete', (response) ->
  console.log JSON.stringify response
.on 'error', (error) ->
  console.log "ERROR on from replicate: #{JSON.stringify error}"

db.changes
  continuous: true
  since: "latest"
  onChange: (change) ->
    console.log "Found a change: #{JSON.stringify change}"
    loadTable()
