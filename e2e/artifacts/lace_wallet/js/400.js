"use strict";(self["webpackChunk_lace_browser_extension_wallet"]=self["webpackChunk_lace_browser_extension_wallet"]||[]).push([[400],{69235:(t,n,e)=>{e.d(n,{Z:()=>a});var r=e(22631);let o;o="function"==typeof window.IntersectionObserver?window.IntersectionObserver:r.Z;const a=o},7267:(t,n,e)=>{e.d(n,{AW:()=>b,F0:()=>R,Gn:()=>generatePath,LX:()=>matchPath,TH:()=>useLocation,UO:()=>useParams,k6:()=>useHistory,l_:()=>Redirect,rs:()=>k,s6:()=>g});var r=e(81665);var o=e(2784);var a=e(25754);var i=e.n(a);var c=e(17547);var u=e(40245);var s=e(61898);var l=e(7896);var p=e(79056);var h=e.n(p);var f=e(48570);var v=e(31461);var d=e(73463);var m=e.n(d);var createNamedContext=function(t){var n=(0,u.Z)();n.displayName=t;return n};var y=createNamedContext("Router-History");var createNamedContext$1=function(t){var n=(0,u.Z)();n.displayName=t;return n};var g=createNamedContext$1("Router");var R=function(t){(0,r.Z)(Router,t);Router.computeRootMatch=function(t){return{path:"/",url:"/",params:{},isExact:"/"===t}};function Router(n){var e;e=t.call(this,n)||this;e.state={location:n.history.location};e._isMounted=false;e._pendingLocation=null;if(!n.staticContext)e.unlisten=n.history.listen(function(t){if(e._isMounted)e.setState({location:t});else e._pendingLocation=t});return e}var n=Router.prototype;n.componentDidMount=function(){this._isMounted=true;if(this._pendingLocation)this.setState({location:this._pendingLocation})};n.componentWillUnmount=function(){if(this.unlisten)this.unlisten()};n.render=function(){return o.createElement(g.Provider,{value:{history:this.props.history,location:this.state.location,match:Router.computeRootMatch(this.state.location.pathname),staticContext:this.props.staticContext}},o.createElement(y.Provider,{children:this.props.children||null,value:this.props.history}))};return Router}(o.Component);var P=function(t){(0,r.Z)(MemoryRouter,t);function MemoryRouter(){var n;for(var e=arguments.length,r=new Array(e),o=0;o<e;o++)r[o]=arguments[o];n=t.call.apply(t,[this].concat(r))||this;n.history=(0,c.PP)(n.props);return n}var n=MemoryRouter.prototype;n.render=function(){return o.createElement(R,{history:this.history,children:this.props.children})};return MemoryRouter}(o.Component);var C=function(t){(0,r.Z)(Lifecycle,t);function Lifecycle(){return t.apply(this,arguments)||this}var n=Lifecycle.prototype;n.componentDidMount=function(){if(this.props.onMount)this.props.onMount.call(this,this)};n.componentDidUpdate=function(t){if(this.props.onUpdate)this.props.onUpdate.call(this,this,t)};n.componentWillUnmount=function(){if(this.props.onUnmount)this.props.onUnmount.call(this,this)};n.render=function(){return null};return Lifecycle}(o.Component);var x;var Z={};var L=1e4;var w=0;function compilePath(t){if(Z[t])return Z[t];var n=h().compile(t);if(w<L){Z[t]=n;w++}return n}function generatePath(t,n){if(void 0===t)t="/";if(void 0===n)n={};return"/"===t?t:compilePath(t)(n,{pretty:true})}function Redirect(t){var n=t.computedMatch,e=t.to,r=t.push,a=void 0!==r&&r;return o.createElement(g.Consumer,null,function(t){t||(0,s.Z)(false);var r=t.history,i=t.staticContext;var u=a?r.push:r.replace;var p=(0,c.ob)(n?"string"==typeof e?generatePath(e,n.params):(0,l.Z)({},e,{pathname:generatePath(e.pathname,n.params)}):e);if(i){u(p);return null}return o.createElement(C,{onMount:function(){u(p)},onUpdate:function(t,n){var e=(0,c.ob)(n.to);if(!(0,c.Hp)(e,(0,l.Z)({},p,{key:e.key})))u(p)},to:e})})}var E={};var M=1e4;var _=0;function compilePath$1(t,n){var e=""+n.end+n.strict+n.sensitive;var r=E[e]||(E[e]={});if(r[t])return r[t];var o=[];var a=h()(t,o,n);var i={regexp:a,keys:o};if(_<M){r[t]=i;_++}return i}function matchPath(t,n){if(void 0===n)n={};if("string"==typeof n||Array.isArray(n))n={path:n};var e=n,r=e.path,o=e.exact,a=void 0!==o&&o,i=e.strict,c=void 0!==i&&i,u=e.sensitive,s=void 0!==u&&u;var l=[].concat(r);return l.reduce(function(n,e){if(!e&&""!==e)return null;if(n)return n;var r=compilePath$1(e,{end:a,strict:c,sensitive:s}),o=r.regexp,i=r.keys;var u=o.exec(t);if(!u)return null;var l=u[0],p=u.slice(1);var h=t===l;if(a&&!h)return null;return{path:e,url:"/"===e&&""===l?"/":l,isExact:h,params:i.reduce(function(t,n,e){t[n.name]=p[e];return t},{})}},null)}var b=function(t){(0,r.Z)(Route,t);function Route(){return t.apply(this,arguments)||this}var n=Route.prototype;n.render=function(){var t=this;return o.createElement(g.Consumer,null,function(n){n||(0,s.Z)(false);var e=t.props.location||n.location;var r=t.props.computedMatch?t.props.computedMatch:t.props.path?matchPath(e.pathname,t.props):n.match;var a=(0,l.Z)({},n,{location:e,match:r});var i=t.props,c=i.children,u=i.component,p=i.render;if(Array.isArray(c)&&0===c.length)c=null;return o.createElement(g.Provider,{value:a},a.match?c?"function"==typeof c?c(a):c:u?o.createElement(u,a):p?p(a):null:"function"==typeof c?c(a):null)})};return Route}(o.Component);function addLeadingSlash(t){return"/"===t.charAt(0)?t:"/"+t}function addBasename(t,n){if(!t)return n;return(0,l.Z)({},n,{pathname:addLeadingSlash(t)+n.pathname})}function stripBasename(t,n){if(!t)return n;var e=addLeadingSlash(t);if(0!==n.pathname.indexOf(e))return n;return(0,l.Z)({},n,{pathname:n.pathname.substr(e.length)})}function createURL(t){return"string"==typeof t?t:(0,c.Ep)(t)}function staticHandler(t){return function(){(0,s.Z)(false)}}function noop(){}var S=function(t){(0,r.Z)(StaticRouter,t);function StaticRouter(){var n;for(var e=arguments.length,r=new Array(e),o=0;o<e;o++)r[o]=arguments[o];n=t.call.apply(t,[this].concat(r))||this;n.handlePush=function(t){return n.navigateTo(t,"PUSH")};n.handleReplace=function(t){return n.navigateTo(t,"REPLACE")};n.handleListen=function(){return noop};n.handleBlock=function(){return noop};return n}var n=StaticRouter.prototype;n.navigateTo=function(t,n){var e=this.props,r=e.basename,o=void 0===r?"":r,a=e.context,i=void 0===a?{}:a;i.action=n;i.location=addBasename(o,(0,c.ob)(t));i.url=createURL(i.location)};n.render=function(){var t=this.props,n=t.basename,e=void 0===n?"":n,r=t.context,a=void 0===r?{}:r,i=t.location,u=void 0===i?"/":i,s=(0,v.Z)(t,["basename","context","location"]);var p={createHref:function(t){return addLeadingSlash(e+createURL(t))},action:"POP",location:stripBasename(e,(0,c.ob)(u)),push:this.handlePush,replace:this.handleReplace,go:staticHandler("go"),goBack:staticHandler("goBack"),goForward:staticHandler("goForward"),listen:this.handleListen,block:this.handleBlock};return o.createElement(R,(0,l.Z)({},s,{history:p,staticContext:a}))};return StaticRouter}(o.Component);var k=function(t){(0,r.Z)(Switch,t);function Switch(){return t.apply(this,arguments)||this}var n=Switch.prototype;n.render=function(){var t=this;return o.createElement(g.Consumer,null,function(n){n||(0,s.Z)(false);var e=t.props.location||n.location;var r,a;o.Children.forEach(t.props.children,function(t){if(null==a&&o.isValidElement(t)){r=t;var i=t.props.path||t.props.from;a=i?matchPath(e.pathname,(0,l.Z)({},t.props,{path:i})):n.match}});return a?o.cloneElement(r,{location:e,computedMatch:a}):null})};return Switch}(o.Component);var U=o.useContext;function useHistory(){return U(y)}function useLocation(){return U(g).location}function useParams(){var t=U(g).match;return t?t.params:{}}var H,A,B,N,O}}]);