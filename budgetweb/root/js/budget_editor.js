BudgetEditor=function() {
    this.expenses={};		// k=oid, v=exp
    this.codes={};		// k=code, v=desc
    this.desc2code={};		// k=desc, v=code
    this.code_descs=[];		// desc's sorted alphabetically
    this.expenses_by_ts=[];
    this.current_oid=0;		// oid of expense currently being edited
}

BudgetEditor.prototype={
    // get all unknown expenses from server, store to editor object:
    fetch_unknown_expenses : function() {
	var editor=this;
	var url='/expense/unknown';
	var settings={
	    type: 'GET',
	    accepts: 'application/json',
	    contentType: 'application/json',
	    error: function(jqXHR, msg, excp) { 
		alert('Unable to fetch "unknown" expenses: error='+jqXHR.status); 
	    },
	    success: function(data, status, jqXHR) { 
		editor.n_expenses=0;
		editor.expenses_by_ts=data.expenses; // should be sorted by ts from server
		for (i in data.expenses) {
		    var exp=data.expenses[i];
		    var oid=exp._id['$oid'];
		    editor.expenses[oid]=exp;
		    editor.n_expenses+=1;
		    exp.rank=parseInt(i);
		}
		var msg=sprintf("%d expenses loaded", editor.n_expenses);
		$('#save_msg').text(msg);
		editor.display_expense();
	    },
	};
	$.ajax(url,settings);
	return false;
    },

    fetch_codes : function() {
	var editor=this;
	var url='/expense/codes';
	var settings={
	    type: 'GET',
	    accepts: 'application/json',
	    contentType: 'application/json',
	    error: function(jqXHR, msg, excp) { 
		alert('Unable to fetch codes: error='+jqXHR.status); 
	    },
	    success: function(data, status, jqXHR) { 
		editor.codes=data;
		var i=0;
		for (code in data) {
		    editor.code_descs[i]=data[code]; // build c2d
		    editor.desc2code[data[code]]=code; // buil d2c
		    i+=1;
		}
		editor.code_descs.sort(); // sort c2d
		$('#exp_code_desc').autocomplete({source: editor.code_descs});
		$('#exp_code_desc').focus();
		// Populate code select:
		populate_select_arr('#exp_code_sel', editor.code_descs)
		populate_select_arr('#code_desc', editor.code_descs);
	    },
	};
	$.ajax(url,settings);
	return false;
	
    },

    // Convert an oid, or null/undefined, or and expense, into an expense
    // if no oid passed, return current exp or first expense 
    // from expenses_by_ts
    oid2exp : function(oid) {
	var expense;
	if (oid != null && oid != undefined) {
	    if (typeof oid == "string") {
		expense=this.expenses[oid];
	    } else if (typeof oid == "object") {
//	    } else if (typeof oid == "object" && typeof oid.code == "number") {
		expense=oid;
	    } else if (typeof oid == "number") {
		expense=this.expenses_by_ts[oid];
	    } else {
		alert("Can't display oid: "+oid);
		return;
	    }
	} else {		// find first
	    if (this.current_oid != 0) {
		expense=this.expenses[this.current_oid]
	    } else {
		expense=this.expenses_by_ts[0];
	    }
	}
	return expense;
    },
    
    // Display a specific expense, or the first in the list if no oid:
    display_expense : function(oid) {
	var expense=this.oid2exp(oid);
	if (expense == null) {
	    alert('No expense for oid='+oid+'???');
	    return;
	}

	// Set display fields:
	$('#exp_oid').text(expense._id['$oid']);
	$('#exp_date').text(expense.date);
	$('#exp_amount').text(sprintf("$%.2f", Math.abs(expense.amount)));
	$('#exp_check_no').text(expense.cheque_no);
	$('#exp_bank_desc').text(expense.bank_desc);
	var code_desc=this.codes[expense.code];
	$('#exp_code_desc').val(code_desc == 'Unknown'? '' : code_desc);

	$("#exp_code_sel").val(expense.code).attr('selected',true);
	$('#exp_rank').text(expense.rank);
	this.current_oid=expense._id['$oid'];
    },

    // Save the current expense using the code defined by code_desc
    // If new_code is null/undefined, send new_desc in it's place
    // and let the server assign a new code as necessary
    save_exp : function(new_code, new_desc) {
	var editor=this;
//	var oid=this.current_oid;
//	var current_exp=this.expenses[oid];
	var current_exp=this.oid2exp();
	current_exp.new_desc=new_desc
	current_exp.code=new_code; // if new_code not defined, server handles

	var url='/expense/'+editor.current_oid;
	var settings={
	    type: 'POST',
	    accepts: 'application/json',
	    contentType: 'application/json',
	    data: JSON.stringify(current_exp),
	    error: function(jqXHR, msg, excp) { 
		alert('Unable to store new code: error='+jqXHR.status); 
	    },
	    success: function(data, status, jqXHR) { 
		// store new code/desc in editor.codes, and
		// add a new option to #exp_code_sel:
		if (editor.codes[data.code]==undefined) {
		    editor.save_code(data.code, data.new_desc);
		    var option_data=new Object();
		    option_data[data['code']]=data.new_desc;
		    console.log('option_data is '+JSON.stringify(option_data));
		    $('#exp_code_sel').append($('<option></option>')
					      .attr("value", data.code)
					      .text(data.new_desc));
		}

		// update current exp w/new code
		var oid=data._id['$oid'];
		var current_exp=editor.oid2exp(oid); // current_exp
		current_exp.code=data.code;
		
		// Update the code select:
		
		// Show a message
		var msg='"'+data.bank_desc+'" saved: code is '+data.code;
		msg+=': '+data.new_desc;
		$('#save_msg').text(msg);
	    },
	};
	$.ajax(url,settings);
    },

    save_and_next_tb : function(event) {
	event.preventDefault();

	var new_desc=$('#exp_code_desc').val();
	// Check for numeric code entered:
	var new_code=parseInt(new_desc);
	if (new_code > 0) {
	    if (this.codes[num_code] != undefined) {
		new_desc=this.codes[num_code];
		console.log('number entered: '+num_code+'->'+new_desc);
	    } else {
		alert('Unknown code: '+new_code);
		// Leave current exp as is
		return;
	    }
	}

	// Look up description:
	var new_code=this.desc2code[new_desc]; // might be undefined; ok
	this.save_exp(new_code, new_desc);
	this.next_exp(1);
    },

    save_and_next_sel : function(event) {
	event.preventDefault();
	var new_code=$('#exp_code_sel :selected').val();
	var new_desc=$('#exp_code_sel option:selected').val();
	this.save_exp(new_code, new_desc);
	this.next_exp(1);
    },

    save_code : function(new_code, new_desc) {
	this.codes[new_code]=new_desc;
	this.desc2code[new_desc]=new_code;
    },

    // Callback for '<' and '>' buttons:
    next_exp : function(di) {
	var current_exp=this.expenses[this.current_oid];
	var rank=(current_exp.rank + di) % this.expenses_by_ts.length;
	this.display_expense(this.oid2exp(rank));
    },

    start_upload : function() {
	console.log('start_upload called');
	$('#file_upload_progress').show();
	return true;
    },

    stop_upload : function(success) {
	console.log('stop_upload called');
	if (success == 1) {
	    $('#result').html("<span class='msg'>Upload successful</span>");
	} else {
	    $('#result').html("<span class='msg'>Upload failed</span>");
	}
	$('#file_upload_progress').hide();
    },
}

$(document).ready(function() {
    var editor=new BudgetEditor();
    this.editor=editor;	// this==document
    editor.fetch_unknown_expenses();
    editor.fetch_codes();
    $('#tabs').tabs();
    
    // Callbacks:
    $('#prev_exp').on('click', function(event) { editor.next_exp(-1) });
    $('#next_exp').on('click', function(event) { editor.next_exp(1) });
    
    $('#exp_code_sel').on('change', function(event) { editor.save_and_next_sel(event) });
    $('#exp_code_desc').on('change', function(event) { editor.save_and_next_tb(event) });
    console.log('ready() done');
    
    $('#upload_form').on('submit', editor.start_upload);
    
    $('#start').datepicker();
    $('#stop').datepicker();

    
})
