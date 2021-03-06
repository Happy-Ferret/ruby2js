# Interactive demo of conversions from Ruby to JS.  Requires wunderbar.
#
# Installation
# ----
#
#   Web server set up to run CGI programs?
#     $ ruby ruby2js.rb --install=/web/docroot
#
#   Want to run a standalone server?
#     $ ruby ruby2js.rb --port=8080
#
#   Want to run from the command line?
#     $ ruby ruby2js.rb [options] [file]
#
#       available options:
#
#         --es2015 
#         --es2016 
#         --es2017 
#         --strict
#         ---filter filter
#         -f filter

require 'wunderbar'

# extract options from the argument list
options = {}
options[:eslevel] = 2015 if ARGV.delete('--es2015')
options[:eslevel] = 2016 if ARGV.delete('--es2016')
options[:eslevel] = 2017 if ARGV.delete('--es2017')
options[:strict] = true if ARGV.delete('--strict')

begin
  # support running directly from a git clone
  $:.unshift File.absolute_path('../../lib', __FILE__)
  require 'ruby2js'

  filters = {
    'functions' => 'ruby2js/filter/functions',
    'es2015' => 'ruby2js/es2015',
    'es2016' => 'ruby2js/es2016',
    'es2017' => 'ruby2js/es2017',
    'jquery'    => 'ruby2js/filter/jquery',
    'vue'       => 'ruby2js/filter/vue',
    'minitest-jasmine' => 'ruby2js/filter/minitest-jasmine',
    'return'    => 'ruby2js/filter/return',
    'require'   => 'ruby2js/filter/require',
    'react'     => 'ruby2js/filter/react',
    'rubyjs'    => 'ruby2js/filter/rubyjs',
    'underscore' => 'ruby2js/filter/underscore',
    'camelCase' => 'ruby2js/filter/camelCase' # should be last
  }

  # allow filters to be selected based on the path
  selected = env['PATH_INFO'].to_s.split('/')

  # add filters from the argument list
  while %w(-f --filter).include? ARGV[0]
    ARGV.shift
    selected << ARGV.shift
  end

  # require selected filters
  filters.each do |name, filter|
    require filter if selected.include?(name) or selected.include? 'all'
  end
rescue Exception => $load_error
end

# command line support
if not env['REQUEST_METHOD'] and not env['SERVER_PORT']
  if ARGV.length > 0
    options[:file] = ARGV.first
    puts Ruby2JS.convert(File.read(ARGV.first), options).to_s
  else
    puts Ruby2JS.convert(STDIN.read, options).to_s
  end  

  exit
end

_html do
  _title 'Ruby2JS'
  _style %{
    textarea {display: block}
    .unloc {background-color: yellow}
    .loc {background-color: white}
  }

  _h1 { _a 'Ruby2JS', href: 'https://github.com/rubys/ruby2js#ruby2js' }
  _form method: 'post' do
    _textarea @ruby, name: 'ruby', rows: 8, cols: 80
    _input type: 'submit', value: 'Convert'

    _input type: 'checkbox', name: 'ast', id: 'ast', checked: !!@ast
    _label 'Show AST', for: 'ast'

    _input type: 'checkbox', name: 'es2017', id: 'es2017', checked: !!@es2017
    _label 'ES2017', for: 'es2017'
  end

  if @ruby
    _div_? do
      raise $load_error if $load_error

      options[:eslevel] = 2017 if @es2017

      ruby = Ruby2JS.convert(@ruby, options)

      if @ast
        walk = proc do |ast, indent=''|
          _div class: (ast.loc ? 'loc' : 'unloc') do
            _ "#{indent}#{ast.type}"
            if ast.children.any? {|child| Parser::AST::Node === child}
              ast.children.each do |child|
                if Parser::AST::Node === child
                  walk[child, "  #{indent}"]
                else
                  _div "#{indent}  #{child.inspect}"
                end
              end
            else
              ast.children.each do |child|
                _ " #{child.inspect}"
              end
            end
          end
        end

        _h2 'AST'
        parsed = Ruby2JS.parse(@ruby).first
        _pre {walk[parsed]}

        if ruby.ast != parsed
          _h2 'filtered AST'
          _pre {walk[ruby.ast]}
        end
      end

      _h2 'JavaScript'
      _pre ruby.to_s
    end
  end
end
