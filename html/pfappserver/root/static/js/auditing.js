function init(){$("#section").on("section.loaded",function(a){$("#report_radius_audit_log .radiud_audit_log_datetimepicker a").click(function(a){a.preventDefault();var b,c=a.currentTarget,d=c.hash.replace(/^#last/,""),e=parseInt(/^\d+/.exec(d)[0]),f=/[^\d]+$/.exec(d)[0];"mins"===f?b=60*e*1e3:"hours"!==f&&"hour"!==f||(b=60*e*60*1e3);var g=new Date,h=new Date(g.getTime()-b),i=$("#start_date"),j=$("#start_time");i.datepicker("setDate",h),j.timepicker("setTime",h.toTimeString());var k=$("#end_date"),l=$("#end_time");return k.attr("value",""),l.attr("value",""),!1}),$('[id$="Empty"]').on("click",'[href="#add"]',function(a){var b=/(.+)Empty/.exec(a.delegateTarget.id),c=b[1],d=b[0];return $("#"+c).trigger("addrow"),$("#"+d).addClass("hidden"),!1});var b=$("#savedSearch"),c=$("#savedSearchForm"),d=$("#search");c.on("submit",function(a){b.modal("hide");var e=new URI(d.attr("action")),f=e.resource()+"?"+d.serialize();return f=f.replace(/^\//,""),c.find('[name="query"]').attr("value",f),$.ajax({url:c.attr("action"),type:c.attr("method")||"POST",data:c.serialize()}).always(function(){b.modal("hide"),c[0].reset()}).done(function(a){location.reload()}).fail(function(a){$("body,html").animate({scrollTop:0},"fast");var b=getStatusMsg(a);showError($("#section h2"),b)}),!1}),b.on("shown",function(a){$(this).find(":input:first").focus()})}),$(window).hashchange(pfOnHashChange(updateSection,"/auditing/radiuslog/")),$(window).hashchange()}$(function(){}),$(function(){var a=new RadiusAuditLog;new RadiusAuditLogView({items:a,parent:$("#section")})});var RadiusAuditLog=function(){};RadiusAuditLog.prototype=new Items,RadiusAuditLog.prototype.id="#radiusAuditLog",RadiusAuditLog.prototype.formName="modalRadiusAuditLog",RadiusAuditLog.prototype.modalId="#modalRadiusAuditLog",RadiusAuditLog.prototype.get=function(a){$.ajax({url:a.url}).always(a.always).done(a.success).fail(function(b){var c=getStatusMsg(b);showError(a.errorSibling,c)})},RadiusAuditLog.prototype.post=function(a){$.ajax({url:a.url,type:"POST",data:a.data}).always(a.always).done(a.success).fail(function(b){var c=getStatusMsg(b);showError(a.errorSibling,c)})};var RadiusAuditLogView=function(a){ItemView.call(this,a);this.parent=a.parent,this.items=a.items};RadiusAuditLogView.prototype=function(){function a(){}return a.prototype=ItemView.prototype,new a}();
//# sourceMappingURL=auditing.js.map