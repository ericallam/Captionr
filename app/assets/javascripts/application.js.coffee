#= require jquery
#= require jquery_ujs
#= require backbone-rails
#= require backbone-localstorage
#= require sprintf
#= require_self
#= require_tree .

# use mustache style templates
_.templateSettings =
  interpolate : /\{\{(.+?)\}\}/g

window.Captionr =
  Models: {}
  Collections: {}
  Views: {}
