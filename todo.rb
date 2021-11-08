require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
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

  def load_list(idx)
    list = session[:lists][idx] if idx && session[:lists][idx]
    return list if list

    session[:error] = "The specified list was not found."
    redirect "/lists"
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

  error = error_for_list list_name
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:id" do
  session[:error]
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
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
  deleted_list = session[:lists].delete_at(id)
  session[:success] = "Successfully deleted #{deleted_list[:name]}"
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:id/todos" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo text
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
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
  @list[:todos].delete_at todo_id
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# Update the status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

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
