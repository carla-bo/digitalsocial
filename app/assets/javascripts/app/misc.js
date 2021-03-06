$(function(){

  var misc = {

    init: function() {
      this.revealableList();
      this.otherFields();
      this.revealOtherField();
      this.autoSizeTextareas();

      if ($('.hr-full').length) {
        this.hrFull();
        this.hrFullResize();
      }
    },

    revealableList: function() {
      $('a.reveal-next').click(function(e){
        var $reveal = $('.revealable:hidden:first');
        $reveal.fadeIn();
        $reveal.find('input:first').focus();

        e.preventDefault();
        return false;
      });
    },

    otherFields: function() {
      $('.input.other').each(function(i, el){
        var $input = $(el).find('input');

        if ($input.val() != "") {
          $(el).show();
          var $radio_buttons = ($(el).prev('.radio_buttons'));
          $radio_buttons.find('input:last').attr('checked', 'checked');
        }
      });
    },

    revealOtherField: function() {
      $('input.radio_buttons').change(function(){
        var $label = $(this).parents('label');
        var name = $(this).attr('name');
        var other_name = name.replace('label', 'label_other');

        if (name != other_name) {
          var $other_input = $('input[name="'+other_name+'"]');

          if ($label.is(':last-child')) {
            $other_input.parents('.input').slideDown('fast', function(){
              $other_input.focus();
            });
          } else {
            $other_input.parents('.input').slideUp('fast', function(){
              $other_input.val("");
            });
          }
        }
      });
    },

    autoSizeTextareas: function() {
      $('textarea.autosize').autosize();
    },

    hrFull: function() {
      var width = $(window).width() - $('.hr-full').offset().left - 1;
      $('.hr-full').css({ width: width });
    },

    hrFullResize: function() {
      $(window).resize(this.hrFull);
    }
  };

  misc.init();
});
