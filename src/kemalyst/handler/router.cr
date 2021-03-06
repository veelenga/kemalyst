require "http/server"
require "radix"

module Kemalyst::Handler
  HTTP_METHODS = %w(get post put patch delete)

  {% for method in HTTP_METHODS %}
    def {{method.id}}(path, &block : HTTP::Server::Context -> _)
      handler = Kemalyst::Handler::Block.new(block)
      Kemalyst::Handler::Router.instance.add_route({{method}}.upcase, path, handler)
    end
    def {{method.id}}(path, handler : HTTP::Handler)
      Kemalyst::Handler::Router.instance.add_route({{method}}.upcase, path, handler)
    end
    def {{method.id}}(path, handler : HTTP::Handler.class)
      Kemalyst::Handler::Router.instance.add_route({{method}}.upcase, path, handler.instance)
    end
    def {{method.id}}(path, handlers : Array(HTTP::Handler))
      handlers.each do |handler|
        Kemalyst::Handler::Router.instance.add_route({{method}}.upcase, path, handler)
      end
    end
    def {{method.id}}(path, handlers : Array(HTTP::Handler.class))
      handlers.each do |handler|
        Kemalyst::Handler::Router.instance.add_route({{method}}.upcase, path, handler.instance)
      end
    end
  {% end %}

  def all(path, handler : HTTP::Handler)
    get path, handler
    put path, handler
    post path, handler
    patch path, handler
    delete path, handler
  end

  # The resources macro will create a set of routes for a list of resources endpoint.
  macro resources(name)
    get "/{{name.id.downcase}}s", {{name.id.capitalize}}Controller::Index
    get "/{{name.id.downcase}}s/new", {{name.id.capitalize}}Controller::New
    post "/{{name.id.downcase}}s", {{name.id.capitalize}}Controller::Create
    get "/{{name.id.downcase}}s/:id", {{name.id.capitalize}}Controller::Show
    get "/{{name.id.downcase}}s/:id/edit", {{name.id.capitalize}}Controller::Edit
    patch "/{{name.id.downcase}}s/:id", {{name.id.capitalize}}Controller::Update
    put "/{{name.id.downcase}}s/:id", {{name.id.capitalize}}Controller::Update
    delete "/{{name.id.downcase}}s/:id", {{name.id.capitalize}}Controller::Delete
  end

  # The resource macro will create a set of routes for a single resource endpoint
  macro resource(name)
    get "/{{name.id.downcase}}/new", {{name.id.capitalize}}Controller::New
    post "/{{name.id.downcase}}", {{name.id.capitalize}}Controller::Create
    get "/{{name.id.downcase}}", {{name.id.capitalize}}Controller::Show
    get "/{{name.id.downcase}}/edit", {{name.id.capitalize}}Controller::Edit
    patch "/{{name.id.downcase}}", {{name.id.capitalize}}Controller::Update
    put "/{{name.id.downcase}}", {{name.id.capitalize}}Controller::Update
    delete "/{{name.id.downcase}}", {{name.id.capitalize}}Controller::Delete
  end

  # The Route holds the information for the node in the tree.
  class Route
    getter method
    getter path
    getter handler

    def initialize(@method : String, @path : String, @handler : HTTP::Handler)
    end
  end

  # The Router Handler redirects traffic to the appropriate Handlers based on
  # the path and method provided.  This allows for filtering which handlers should
  # be accessed.  Several macros are provided to help with registering the
  # path and method handlers.  Routes should be defined in the
  # `config/routes.cr` file.
  #
  # An example of a route would be:
  # ```
  # get "/", DemoController::Index.instance
  # ```
  #
  # You may also pass in a block similar to sinatra or kemal:
  # ```
  # get "/" do |context|
  #   text "Great job!", 200
  # end
  # ```
  #
  # You may chain multiple handlers in a route using an array:
  # ```
  # get "/", [BasicAuth.instance("username", "password"),
  #           DemoController::Index.instance]
  # ```
  #
  # or:
  # ```
  # get "/", BasicAuth.instance("username", "password") do |context|
  #   text "This is secured by BasicAuth!", 200
  # end
  # ```
  #
  # This is how you would configure a WebSocket:
  # ```
  # get "/", [WebSocket.instance(ChatController::Chat.instance),
  #           ChatController::Index.instance]
  # ```
  #
  # The `Chat` class would have a `call` method that is expecting an
  # `HTTP::WebSocket` to be passed which it would maintain and properly handle
  # messages to and from it.  Check out the sample Chat application to get an idea
  # on how to do this.
  #
  # You can use any of the following methods: `get, post, put, patch, delete, all`
  #
  # You can use a `*` to chain a handler for all children of this path:
  # ```
  # all "/posts/*", BasicAuth.instance("admin", "password")
  #
  # # all of these will be secured with the BasicAuth handler.
  # get "/posts/:id", DemoController::Show.instance
  # put "/posts/:id", DemoController::Update.instance
  # delete "/posts/:id", DemoController::Delete.instance
  # ```
  # You can use `:variable` in the path and it will set a
  # context.params["variable"] to the value in the url.
  class Router < Base
    property tree :  Radix::Tree(Array(Kemalyst::Handler::Route))

    # class method to return a singleton instance of this Controller
    def self.instance
      @@instance ||= new
    end

    def initialize
      @tree = Radix::Tree(Array(Kemalyst::Handler::Route)).new
    end

    def call(context)
      context.response.content_type = "text/html"
      process_request(context)
    end

    # Processes the route if it's a match. Otherwise renders 404.
    def process_request(context)
      method = context.request.method
      # Is there an overrided _method parameter?
      method = context.params["_method"] if context.params.has_key? "_method"
      result = lookup_route(method.as(String), context.request.path)
      if result.found?
        if routes = result.payload
          # Add routing params to context.params
          result.params.each do |key, value|
            context.params[key] = value
          end

          # chain the routes
          0.upto(routes.size - 2) do |i|
            if route = routes[i]
              if next_route = routes[i + 1]
                route.handler.next = next_route.handler
              end
            end
          end

          if route = routes.first
            route.handler.call(context)
          end

          # clean state
          routes.each do |route|
            route.handler.next = nil if route
          end
        else
          raise Kemalyst::Exceptions::RouteNotFound.new("Requested payload: '#{method.as(String)}:#{context.request.path}' was not found.")
        end
      else
        raise Kemalyst::Exceptions::RouteNotFound.new("Requested path: '#{method.as(String)}:#{context.request.path}' was not found.")
      end
      context
    end

    # Adds a given route to routing tree. As an exception each `GET` route additionaly defines
    # a corresponding `HEAD` route.
    def add_route(method, path, handler)
      add_to_tree(method, path, Route.new(method, path, handler))
      add_to_tree("HEAD", path, Route.new("HEAD", path, handler)) if method == "GET"
    end

    # Check if a route is defined and returns the lookup
    def lookup_route(verb, path)
      @tree.find method_path(verb, path)
    end

    private def add_to_tree(method, path, route)
      node = method_path(method, path)
      result = @tree.find(node)
      if result && result.found?
        result.payload << route
      else
        routes = [] of Kemalyst::Handler::Route
        routes << route
        @tree.add(node, routes)
      end
    end

    private def method_path(method : String, path)
      "#{method.downcase}/#{path}"
    end
  end
end
