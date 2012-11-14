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
		    editor.code_descs[i]=data[code];
		    editor.desc2code[data[code]]=code;
		    i+=1;
		}
		editor.code_descs.sort();
		$('#exp_code_desc').autocomplete({source: editor.code_descs});
		$('#exp_code_desc').focus();
		jQuery.each(editor.code_descs, function(idx, code) {
		    $('#exp_code_sel').append($('<option>', {
			value: editor.desc2code[code], text: code
		    }));
		});
		
		console.log('loaded codes');
	    },
	};
	$.ajax(url,settings);
	return false;
	
    },

    // Convert an oid, or null/undefined, or and expense, into an expense
    oid2exp : function(oid) {
	var expense;
	if (oid != null && oid != undefined) {
	    if (typeof oid == "string") {
		expense=this.expenses[oid];
	    } else if (typeof oid == "object") {
//	    } else if (typeof oid == "object" && typeof oid.code == "number") {
		expense=oid;
	    } else {
		alert("Can't display oid: "+oid);
		return;
	    }
	} else {		// find first
	    expense=this.expenses_by_ts[0];
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
	console.log('displaying expense #'+expense.rank);

	// Set display fields:
	$('#exp_oid').text(expense._id['$oid']);
	$('#exp_date').text(expense.date);
	$('#exp_amount').text(sprintf("$%.2f", Math.abs(expense.amount)));
	$('#exp_check_no').text(expense.cheque_no);
	console.log('check_no: '+expense.check_no);
	console.log('cheque_no: '+expense.cheque_no);
	$('#exp_bank_desc').text(expense.bank_desc);
	var code_desc=this.codes[expense.code];
	console.log('code is '+expense.code+', desc is '+code_desc);
	if (code_desc == 'Unknown') {
	    $('#exp_code_desc').val('');
	} else {
	    $('#exp_code_desc').val(code_desc);
	}
	$('#exp_rank').text(expense.rank);
	this.current_oid=expense._id['$oid'];
    },

    // Save the current expense using the code defined by code_desc
    save_exp : function(new_code) {
	var oid=this.current_oid;
	console.log('save_exp: oid is '+oid);
	var current_exp=this.expenses[oid];
	current_exp.code=new_code;
	console.log('save_exp: saving '+JSON.stringify(current_exp));
	var url='/expense/'+oid;
	var settings={
	    type: 'POST',
	    accepts: 'application/json',
	    contentType: 'application/json',
	    data: JSON.stringify(current_exp),
	    error: function(jqXHR, msg, excp) { 
		alert('Unable to store new code: error='+jqXHR.status); 
	    },
	    success: function(data, status, jqXHR) { 
		console.log(current_exp.bank_desc+' saved: new code is '+new_code);
	    },
	};
	$.ajax(url,settings);
    },

    save_and_next_tb : function(event) {
	event.preventDefault();
	var new_desc=$('#exp_code_desc').val();
	var new_code=this.desc2code[new_desc];
	console.log('santb: new_desc is '+new_desc+', new_code is '+new_code);
	if (new_code == null) {
	    console.log('calling create_code');
	    new_code=this.create_code(new_desc);
	}
	this.save_exp(new_code);
	this.next_exp(1);
    },

    save_and_next_sel : function(event) {
	event.preventDefault();
	var new_code=$('#exp_code_sel :selected').val();
	console.log('sans: selected is '+new_code);
	this.save_exp(new_code);
	this.next_exp(1);
    },

    // Create and store a new code:
    create_code : function(new_desc) {
	var editor=this;
	var url='/expense/codes';
	var new_code;
	var settings={
	    type: 'POST',
	    accepts: 'application/json',
	    contentType: 'application/json',
	    data: JSON.stringify({'new_desc' : new_desc}),
	    error: function(jqXHR, msg, excp) { 
		alert('Unable to store new code: error='+jqXHR.status); 
	    },
	    success: function(data, status, jqXHR) { 
		new_code=data.new_code;
		new_desc=data.new_desc;
		console.log('new code added: '+new_code+'->'+new_desc);
		editor.codes[new_code]=new_desc;
		editor.desc2code[new_desc]=new_code;
	    },
	};
	$.ajax(url,settings);
	return new_code;
    },

    // Callback for '<' and '>' buttons:
    next_exp : function(di) {
	var current_exp=this.expenses[this.current_oid];
	var rank=(current_exp.rank + di) % this.expenses_by_ts.length;
	var to_display=this.expenses_by_ts[rank];
	this.display_expense(to_display);
    }
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
})