require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
  set :erb, :cache => false
end

helpers do
  def list_completed?(list)
    list[:todos].any? && list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def todos_progress(list)
    "#{list[:todos].count { |todo| todo[:completed] }} / #{list[:todos].size}"
  end

  def sort_lists(lists, &block)
    lists.partition { |list| !list_completed?(list) }
         .flatten
         .each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    todos.partition { |todo| todo[:completed] == false }
         .flatten
         .each { |todo| yield todo, todos.index(todo) }
  end

  def load_list(id)
    list = session[:lists].find { |list| list[:id] == id }
    return list if list

    session[:error] = "The specified list was not found."
    redirect "/lists"
  end

  def next_element_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return error message if name is invalid, otherwise return nil.
def error_for_list(list_name)
  if session[:lists].any? { |list| list[:name] == list_name }
    "The list name must be unique."
  elsif !(1..200).cover? list_name.size
    "The list name must be between 1 and 200 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a todo list
get '/lists/:id' do
  id = params[:id].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# Render the edit list form
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list list_name
  if error && list_name != session[:lists][id][:name]
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = "The list has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }

    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

def error_for_todo(todo_text)
  if session[:lists].any? { |list| list[:name] == todo_text }
    "Todo must be unique."
  elsif !(1..200).cover? todo_text.size
    "Todo must be between 1 and 200 characters."
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end
