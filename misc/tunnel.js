'use strict'

var url = require('url')
  , qs = require('querystring')
  , http = require('http')
  , https = require('https')
  , npmconf = require('npmconf')
  , tunnel = require('tunnel-agent')
  , log = require('printit')({prefix: 'tunnel\t'})

function parseURL(uri) {
    if(!uri) return null
    return url.parse(uri)
}

function pick(what, obj) {
    var opts = Object.keys(obj)
    var selected = null
    for(var i = 0, l= opts.length; i < l; i++){
        var value = obj[opts[i]]
        if(value && value != '')
            log.info('possible', what, 'from', opts[i], '=', value)
            selected = value
    }
    log.info('selected', what, selected)
    return selected
}

function logOptions(label, options){
    log.info(label, options.method, options.protocol, options.host,
        options.port, options.path,
        (options.__tunnelSetup ? '__tunnelSetup' : ''), 'agent=' +
        (options.agent && options.agent.constructor.name) );
}

var defaultProxyHeaderWhiteList = [
    'accept', 'accept-charset', 'accept-encoding', 'accept-language',
    'accept-ranges', 'cache-control', 'content-encoding', 'content-language',
    'content-location', 'content-md5', 'content-range', 'content-type',
    'connection', 'date', 'expect', 'max-forwards', 'pragma', 'referer',
    'te', 'user-agent', 'via'
]
var defaultProxyHeaderExclusiveList = [ 'proxy-authorization' ]

var ORIGINALS = {
    http: {lib: http, request: http.request, globalAgent: http.globalAgent},
    "http:": {lib: http, request: http.request, globalAgent: http.globalAgent},
    https: {lib: https, request: https.request, globalAgent: https.globalAgent},
    "https:": {lib: https, request: https.request, globalAgent: https.globalAgent}
};

module.exports.initialize = function(callback){
    npmconf.load({}, function (err, conf) {
        ORIGINALS.http.proxy = parseURL(pick("proxy for http", {
            "env.http_proxy" : process.env.http_proxy,
            "env.HTTP_PROXY" : process.env.HTTP_PROXY,
            "npm http-proxy" : conf.get("http-proxy")
        }));
        if(ORIGINALS.http.proxy)
            http.request = replaceRequest.bind(http, "http")

        ORIGINALS.https.proxy = parseURL(pick("proxy for https", {
            "env.https_proxy" : process.env.https_proxy,
            "env.HTTPS_PROXY" : process.env.HTTPS_PROXY,
            "npm https-proxy" : conf.get("https-proxy")
        }));
        if(ORIGINALS.https.proxy)
            https.request = replaceRequest.bind(https, 'https')

        callback(null)
    });
}

function replaceRequest(protocol, options, callback){
    if(typeof options === 'string') options = parseURL(options);
    logOptions('ORIGINAL', options)
    if(!options.__tunnelSetup){
        options.protocol = protocol + ':'
        var proxy = ORIGINALS[protocol].proxy
        if(proxy){
            options.__tunnelSetup = true
            applyTunnelProxy(options, proxy)
        }
        options.protocol = undefined
    }
    var httpOrHttps = ORIGINALS[protocol]
    return httpOrHttps.request.call(httpOrHttps.lib, options, callback)
}

function applyTunnelProxy(options, proxy) {
    // Setup Proxy Headers and Proxy Headers Host
    // Only send the Proxy White Listed Header names
    var proxyHeaders = {}
    defaultProxyHeaderWhiteList.forEach(function(header){
        if(options.headers[header])
          proxyHeaders[header] = options.headers[header]
    });
    var isHttps = options.protocol === 'https:'
    proxyHeaders.host = (options.hostname || options.host) + ':' +
      (options.port ? options.port : isHttps ? '443' : '80')

    // Set Agent from Tunnel Data
    var uriProtocol = (options.protocol === 'https:' ? 'https' : 'http')
    var proxyProtocol = (proxy.protocol === 'https:' ? 'Https' : 'Http')
    options.agent = tunnel[uriProtocol + 'Over' + proxyProtocol]({
        proxy : {
            __tunnelSetup: true,
            host      : proxy.hostname,
            port      : +proxy.port,
            proxyAuth : proxy.auth,
            headers   : proxyHeaders
        },
        headers            : options.headers,
        rejectUnauthorized : options.rejectUnauthorized,
        secureOptions      : options.secureOptions,
        secureProtocol     : options.secureProtocol
     });
     options.agent.request = ORIGINALS[proxy.protocol].request
                             .bind(ORIGINALS[proxy.protocol].lib)

    var usetunnel = options.protocol === 'https:'
    if (proxy && !usetunnel) {
        options.path = (options.protocol + '//' + options.host +
            (options.port ? ':' + options.port : '') + options.path)

        options.port = proxy.port
        options.host = proxy.hostname
        options.protocol = proxy.protocol
        if(proxy.auth)
            options.headers['proxy-authorization'] = 'Basic ' + new Buffer(
                proxy.auth.split(':')
                .map(function(item) { return qs.unescape(item) })
                .join(':')
            ).toString('base64')

        logOptions('  CHANGED', options)
    }else{
        logOptions('  ADDED AGENT', options)
        log.error(new Error().stack.split("\n").slice(2, 4).join("\n"))
    }

}
