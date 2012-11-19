if(!Object.keys) Object.keys = function(o){
   if (o !== Object(o))
      throw new TypeError('Object.keys called on non-object');
   var ret=[],p;
   for(p in o) if(Object.prototype.hasOwnProperty.call(o,p)) ret.push(p);
   return ret;
}

function toggle_more(id, vis) { 
  if (vis) {
    $('#'+id+'_'+'long').show();
    $('#'+id+'_'+'short').hide();
  } else {
    $('#'+id+'_'+'long').hide();
    $('#'+id+'_'+'short').show();
  }
  return false;
}

// populate a select with an array
// sel_id should include '#'
// option value is index of array
// text is arr[i]
function populate_select_arr(sel_id, arr) {
    jQuery.each(arr, function(idx, val) {
	$(sel_id).append($('<option>', {
	    value: arr[idx], text: val
	}));
    });
}

function show_args() {
  console.log($('#start_date').val());
  console.log($('#end_date').val());
  console.log($('#report_code option:selected').val());
}

