# as much as I hate external fixtures, in this case the file #render is called
# from matters so this controller must be split off into its own file
class Controller3 < Merb::Controller
  def index; render; end
end

__END__
@@ foo
fou

@@ controller3/index.html.erb
3rdctrl-index

@@ controller3/qwerty.xml.haml
funky
