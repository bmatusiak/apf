﻿/**************************************************************************************************
BSD License
The BSD License (http://www.opensource.org/licenses/bsd-license.php) specifies the terms and
conditions of use for FAVideo:

Copyright (c) 2007. Adobe Systems Incorporated.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted
provided that the following conditions are met:

  • Redistributions of source code must retain the above copyright notice, this list of conditions
    and the following disclaimer.
  • Redistributions in binary form must reproduce the above copyright notice, this list of
    conditions and the following disclaimer in the documentation and/or other materials provided
	with the distribution.
  • Neither the name of Adobe Systems Incorporated nor the names of its contributors may be used
    to endorse or promote products derived from this software without specific prior written
	permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIESOF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


For more information and updates for FAVideo, please visit:
http://www.adobe.com/go/favideo/
**************************************************************************************************/

import flash.external.ExternalInterface;
import flash.system.Security;
import flash.utils.*;
import flash.geom.ColorTransform;
import mx.utils.Delegate;

import com.adobe.favideo.managers.UIManager;
import com.adobe.favideo.VideoState;
import com.adobe.favideo.VideoScaleMode;
import com.adobe.favideo.VideoAlign;
import com.adobe.favideo.views.BaseView;
import com.adobe.favideo.utils.Tick;
import com.adobe.favideo.views.Image;

class com.adobe.favideo.FAVideo extends BaseView {
// Constants:
	private static var EI_ERROR:String = 'eiError';
	private static var DEBUG:Boolean   = false;
	public var NOSKIN:Boolean          = true;
	
// Private Properties:
	private var _source:String;
	private var _skinAutoHide:Boolean;
	private var _autoPlay:Boolean;
	private var defaultVolume:Number;
	private var _totalTime:Number;
	private var _state:String;
	private var _videoScaleMode:String;
	private var _videoAlign:String;
	private var _themeColor:Number;
	private var _playheadUpdateInterval:Number;
	private var _playheadUpdateInt:Number;
	private var _flvWidth:Number;
	private var _flvHeight:Number;
	private var _skinVisible:Boolean;
	private var __width:Number;
	private var __height:Number;
	private var _autoLoad:Boolean = true;
	private var _previewImagePath:String;
	private var _inited:Boolean;
	private var previewImage:Image;
	private var _pauseAfterSeek:Boolean;
	private var initialVideoPath:String = "";
	private var flvHeightOffset:Number = 0; //Used when the skin is under the flv file.
	private var playerID:String;
	private var secureDomain:String;
	private var currentState:Object;
	private var jsPropMap:Object;
	private var lastSentPlayheadTime:Number;
	private var clickToTogglePlayDelegate:Function;
	private var _clickToTogglePlay:Boolean;
	private var ticker:Tick;
	private var audioControl:Sound;
	private var uiManager:UIManager;
	private var loadingDelegate:Function;
	private var resizeDelegate:Function;
	private var initDelegate:Function;
	private var fullscreenDelegate:Function;
	private var keyListener:Object;
	private var lastSize:Object;
	private var netConn:NetConnection;
	private var netStream:NetStream;
	private var lastBytesLoaded:Number;
	
// UI Elements:
	private var video:Video;
	private var eiError:MovieClip;
	private var playPauseBtn:MovieClip;
	
// Initialization:
	private function FAVideo() { super(); }
	private function onLoad():Void { configUI(); }
	
// Public Methods:
	// START Interface for the UIManager
	public function get x():Number { return 0; }
	public function get y():Number { return 0; }
	
	public function get volume():Number { return audioControl.getVolume(); }
	public function set volume(volume:Number):Number { setVolume(volume); }
	
	public function get state():String { return _state; }
	public function get totalTime():Number { return _totalTime; }
	public function get playheadTime():Number { return netStream.time; }
	public function get contentPath():String { return _source; }
	
	public function get width():Number { return x + __width; }
	public function get height():Number { return y + (__height-flvHeightOffset); }
	
	public function get bytesLoaded():Number { return netStream.bytesLoaded; }
	public function get bytesTotal():Number { return netStream.bytesTotal; }
	
	public function seekPercent(value:Number):Void {
		if (value < 0 || value > 100 || totalTime == undefined || totalTime == null || totalTime <= 0)
			return;
		seek(totalTime * value / 100);
	}
	
	public function skinError():Void {
		sendEvent('debug', {msg:'skinError'});
	}
	
	public function skinLoaded():Void {
		//If the height is bigger than the actual height we assume we have a skin underneith.
		//so store a offset var, so we can resize the video correctly.
		flvHeightOffset = (_height > __height)?_height - __height:0;
		sendEvent('debug', {msg:'skinLoaded - ' + flvHeightOffset + ', ' + __width + 'x' + __height});
		try {
			setSize(__width, __height);
		}
		catch(e:Error) {
			sendEvent('debug', {msg: 'resize error: ' + e.toString()});
		}
		sendEvent('debug', {msg: 'FAVideo resized.'});
		var disable:Boolean = (_state == VideoState.CONNECTION_ERROR) || (_state ==  VideoState.DISCONNECTED) || (_source == undefined && initialVideoPath == "");
		enableInterface(!disable);
	}
	
	public function _scrubFinish():Void {
		// do nothing.
	}
	
	public function _scrubStart():Void {
		// do nothing.
	}
	// END Interface for the UIManager
	
	
	public function playVideo(source:String, totalTime:Number):Void {
		initialVideoPath = "";
		
		_source    = (source == null)    ? _source    : source;
		_totalTime = (totalTime == null) ? _totalTime : totalTime;
		
		setAutoPlay(true);
		previewImage.visible =  false;
		enableInterface(true);
		
		if (_source == source && _state == VideoState.PAUSED || _state == VideoState.STOPPED) {
			pause(false);
		}
		else {
			load();
		}
	}
	
	public function loadVideo(source:String, totalTime:Number):Void {
		initialVideoPath = "";
		
		_source    = source;
		_totalTime = totalTime;
		setAutoPlay(false);
		enableInterface(true);
		
		load();
	}
	
	public function pause(value:Boolean):Void {
		if (value == null) {
			value = VideoState.PAUSED?false:true;
		}
		if (!Boolean(value) && initialVideoPath != "") {
			playVideo(initialVideoPath);
		}
		else if (value) {
			netStream.pause(true);
			setState(VideoState.PAUSED);
		}
		else {
			netStream.pause(false);
			setState(VideoState.PLAYING);
			previewImage.visible =  false;
			setPlayheadUpdateInterval(_playheadUpdateInterval);
			trackLoading();
		}
	}
	
	public function stop():Void {
		seek(0);
		pause(true);
		if (!NOSKIN)
			dispatchEvent({type:'playheadUpdate', playheadTime:0, totalTime:_totalTime}); //Event for the UIManager
		setState(VideoState.STOPPED);
	}
	
	public function seek(seekToSeconds:Number):Void {
		setState(VideoState.SEEKING);
		
		if (seekToSeconds < 0) {
			seek(0);
			_pauseAfterSeek = true;
		}
		else if (seekToSeconds > totalTime) {
			seek(totalTime);
			_pauseAfterSeek = true;
		}
		else {
			netStream.seek(seekToSeconds);
		}
	}
	
// Private Methods:
	private function initConnection():Boolean {
		if (netConn && netStream) return true;
		
		if (!netConn) {
			netConn = new NetConnection();
		}
		
		var canConnect:Boolean = netConn.connect(null);
		
		if (!canConnect) return false;
		
		if (!netStream) {
			netStream = new NetStream(netConn);
			
			netStream.onCuePoint = Delegate.create(this, onNetStreamCuePoint);
			netStream.onMetaData = Delegate.create(this, onNetStreamMetaData);
			netStream.onStatus   = Delegate.create(this, onNetStreamStatus);
		}
		
		video.attachVideo(netStream);
		this.attachAudio(netStream);
		audioControl = new Sound(this);
		if (defaultVolume)
			audioControl.setVolume(defaultVolume);
		
		return true;
	}
	
	private function load():Void {
		if (!_source) return;

		if (initConnection()) {
			netStream.play(_source);
			trackLoading();
			setState(VideoState.LOADING);
		}
		else {
			setState(VideoState.CONNECTION_ERROR);
		}
	}
	
	private function setAutoLoad(value:Boolean):Void {
		_autoLoad = value;
	}
	
	private function trackLoading():Void {
		ticker.addEventListener('tick', loadingDelegate);
	}
	
	private function onLoading(event:Object):Void {
		if (lastBytesLoaded == bytesLoaded) return;
		
		if (bytesLoaded > 4 && bytesLoaded == bytesTotal)
			ticker.removeEventListener('tick', loadingDelegate);
		
		lastBytesLoaded = bytesLoaded;
		
		sendEvent('progress', {bytesLoaded:bytesLoaded, bytesTotal:bytesTotal});
		if (!NOSKIN)
			dispatchEvent({type:'progress', bytesLoaded:bytesLoaded, bytesTotal:bytesTotal}); //Event for the UIManager
	}
	
	private function onNetStreamStatus(infoObject:Object):Void {
		switch (infoObject.code) {
			case 'NetStream.Buffer.Empty':
				setState(VideoState.BUFFERING);
				break;
			case 'NetStream.Buffer.Full':
				setState(VideoState.PLAYING);
				//pause(false);
				break;
			case 'NetStream.Buffer.Flush':
				break;
			case 'NetStream.Play.Start':
				if (!_autoPlay) {
					pause(true);
					dispatchEvent({type:'ready'}); //Event for the UIManager
					sendEvent('ready');
				} else {
					setPlayheadUpdateInterval(_playheadUpdateInterval || 250);
					setState(VideoState.PLAYING);
				}
				break;
			case 'NetStream.Play.StreamNotFound':
				setState(VideoState.CONNECTION_ERROR);
				ticker.removeEventListener('tick', loadingDelegate);
				break;
			case 'NetStream.Seek.InvalidTime':
			case 'NetStream.Seek.Notify':
				sendEvent('status', infoObject);
				if (state == VideoState.STOPPED || _pauseAfterSeek) {
					delete _pauseAfterSeek;
					netStream.pause(true);
				}
				else {
					netStream.pause(false);
				}
				break;
			case 'NetStream.Play.Stop':
				setState(VideoState.STOPPED);
				sendEvent('complete');
				stop();
				break;
			default:
		}
	}
	
	private function onNetStreamMetaData(metaData:Object):Void {
		if (metaData.duration && !_totalTime) {
			setTotalTime(metaData.duration);
		}
		
		if (metaData.width && metaData.width) {
			_flvWidth = metaData.width;
			_flvHeight = metaData.height;
		}
		
		sendEvent('metaData', metaData);
		if (!NOSKIN)
			dispatchEvent({type:'metadataReceived'}); //Event for the UIManager
	}
	
	private function onNetStreamCuePoint(cuePoint:Object):Void {
		sendEvent('cuePoint', cuePoint);
	}
	
	/**
	* @private
	* 
	*/
	private function setState(state:String):Void {
		_state = state;
		if (!NOSKIN)
			dispatchEvent({type:'stateChange', state:_state}); //Event for the UIManager
		
		switch (state) {
			case EI_ERROR:
				enableInterface(false);
				eiError._visible = true;
				break;
			case VideoState.PAUSED:
				sendEvent('stateChange', {state:VideoState.PAUSED});
				break;
			case VideoState.PLAYING:
				sendEvent('stateChange', {state:VideoState.PLAYING});
				break;
			case VideoState.STOPPED:
				sendEvent('stateChange', {state:VideoState.STOPPED});
				break;
			case VideoState.BUFFERING:
				sendEvent('stateChange', {state:VideoState.BUFFERING});
				break;
			case VideoState.LOADING:
				sendEvent('stateChange', {state:VideoState.LOADING});
				break;
			case VideoState.SEEKING:
				sendEvent('stateChange', {state:VideoState.SEEKING});
				break;
			case VideoState.CONNECTION_ERROR:
				sendEvent('stateChange', {state:VideoState.CONNECTION_ERROR});
				halt();
				break;
			case VideoState.DISCONNECTED:
				sendEvent('stateChange', {state:VideoState.DISCONNECTED});
				halt();
				break;
			default:
		}
	}
	
	private function halt():Void {
		removePlayheadUpdateInt();
		ticker.removeEventListener('tick', loadingDelegate);
	}
	
	/**
	 * Possible Values are: "maintainAspectRatio", "noScale", and "exactFit"
	 * 
	 * @default maintainAspectRatio
	 */
	private function onResize():Void {
		sendEvent('debug', {msg:'onResize called'});
		switch (_videoScaleMode) {
			case VideoScaleMode.NO_SCALE:
				sendEvent('debug', {msg: 'resizing video NOSCALE...START'});
				video._width = video.width;
				video._height = video.height;
				break;
			case VideoScaleMode.MAINTAIN_ASPECT_RATIO:
				sendEvent('debug', {msg: 'resizing video MAINTAIN_ASCPECT_RATIO...START'});
				sizeVideo(true);
				break;
			case VideoScaleMode.EXACT_FIT:
				sendEvent('debug', {msg: 'resizing video EXACT_FIT...START'});
				sizeVideo(false);
				break;
		}
		sendEvent('debug', {msg: 'resizing video...END'});
		
		var newWidth = __width;
		var newHeight = __height - flvHeightOffset;
		
		//Posistion Video
		sendEvent('debug', {msg: 'video alignment: ' + _videoAlign});
		switch (_videoAlign) {
			case VideoAlign.BOTTOM:
				video._y =  newHeight - video._height;
				video._x = (newWidth - video._width) / 2;
				break;
			case VideoAlign.BOTTOM_LEFT:
				video._y =  Stage.height - video._height;
				video._x = 0;
				break;
			case VideoAlign.BOTTOM_RIGHT:
				video._y =  newHeight - video._height;
				video._x = newWidth - video._width;
				break;
			case VideoAlign.TOP:
				video._y = 0;
				video._x = (newWidth - video._width)/2;
				break;
			case VideoAlign.TOP_LEFT:
				video._y = video._x = 0;
				break;
			case VideoAlign.TOP_RIGHT:
				video._y = 0;
				video._x = newWidth - video._width;
				break;
			case VideoAlign.CENTER:
				video._y =  (newHeight - video._height) / 2;
				video._x = (newWidth - video._width) / 2;
				break;
			case VideoAlign.LEFT:
				video._y =  (newHeight - video._height) / 2;
				video._x = 0;
				break;
			case VideoAlign.RIGHT:
				video._y = (newHeight - video._height) / 2;
				video._x = newWidth - video._width;
				break;
			default:
		}
		
		previewImage._x = video._x;
		previewImage._y = video._y;
		
		playPauseBtn._width = newWidth;
		playPauseBtn._height = newHeight;
		
		lastSize = {
			width: width,
			height: height
		};
		
		dispatchEvent({type:'resize', x:video._x, y:video._y, width:width, height:width}); //Event for the UIManager
	}
	
	private function sizeVideo(maintainAspectRatio:Boolean):Void {
		var w:Number = __width;
		var h:Number = __height - flvHeightOffset;
		
		var vidWidth:Number  = !video || video.width  == 0 ? __width  : video.width;
		var vidHeight:Number = !video || video.height == 0 ? __height : video.height;
		sendEvent('debug', {msg: 'sizing video: ' + w + 'x' + h + ', ' + vidWidth + 'x' + vidHeight});
		
		if (maintainAspectRatio) { // Find best fit.
			var containerRatio:Number = w / h;
			var imageRatio:Number     = vidWidth / vidHeight;
			
			if (containerRatio < imageRatio) {
				h = w / imageRatio;
			}
			else {
				w = h * imageRatio;
			}
		}
		
		previewImage.setSize(w, h);
		
		playPauseBtn._width  = w;
		playPauseBtn._height = h;
		
		playPauseBtn._y = playPauseBtn._x = 0;
		sendEvent('debug', {msg:'setting video dims to : ' + w + 'x' + h});
		video._width  = w;
		video._height = h;
	}
	
	private function togglePlay():Void {
		pause(_state == VideoState.PLAYING);
	}
	
	private function onDownloadSource():Void {
		getURL('http://www.adobe.com/go/favideo/', '_blank');
	}
	
	private function enableInterface(enable:Boolean):Void {
		uiManager.controlsEnabled = enable;
		playPauseBtn._visible =  (enable) ? _clickToTogglePlay : enable;
	}
	
	private function configUI():Void {
		eiError._visible = false;
		ticker._visible  = false;
		
		loadingDelegate           = Delegate.create(this, onLoading);
		clickToTogglePlayDelegate = Delegate.create(this, togglePlay);
		initDelegate              = Delegate.create(this, init);
		resizeDelegate            = Delegate.create(this, onResize);
		
		uiManager = new UIManager(this);
		uiManager.skin_mc._visible = false;
		
		//ticker.addEventListener('tick', Delegate.create(this, sendNewPlayerState));
		
		_videoScaleMode = VideoScaleMode.MAINTAIN_ASPECT_RATIO;
		_videoAlign     = VideoAlign.CENTER;
		
		playPauseBtn.onRelease = clickToTogglePlayDelegate;
		playPauseBtn._visible  = false;
		
		var cm:ContextMenu = new ContextMenu();
		cm.hideBuiltInItems();
		_root.menu = cm;
		
		/**
		* Current state for the JS
		* Sample: flvWidth: {prop:'_flvWidth', value:undefined}
		* 			- flvWidth: JS Property to set
		*			- prop: Internal Flash property
		*			- value: Last sent value, default is undefined
		* JS always gets a full packet at-least once.
		* sendNewPlayerState is called on tick, and sends a delta packet to JS
		* 
		*/
		currentState =  { 
			flvWidth: {prop:'_flvWidth', value:undefined}, 
			flvHeight:{prop:'_flvHeight',  value:undefined},
			totalTime: {prop:'_totalTime', value:undefined},
			bytesLoaded: {prop:'bytesLoaded', value:undefined},
			bytesTotal: {prop:'bytesTotal', value:undefined},
			state: {prop:'_state', value:undefined},
			volume: {prop:'volume', value:undefined},
			playheadTime: {prop:'playheadTime', value:undefined}
		}
		
		/**
		* Properties set from JS, and their corresponding Flash methods
		*/
		jsPropMap = {
			clickToTogglePlay:'setClickToTogglePlay',
			autoPlay:'setAutoPlay',
			volume:'setVolume',
			bufferTime:'setBufferTime',
			videoScaleMode:'setVideoScaleMode',
			videoAlign:'setVideoAlign',
			playheadUpdateInterval:'setPlayheadUpdateInterval',
			skinAutoHide:'setSkinAutoHide',
			playHeadTime:'setPlayheadTime',
			totalTime:'setTotalTime',
			skinPath:'loadSkin',
			skinVisible:'setSkinVisible',
			autoLoad:'setAutoLoad',
			previewImagePath:'setPreviewImagePath',
			themeColor:'setThemeColor'
		}
		
		Stage.scaleMode = 'noScale';
		Stage.align     = 'TL';
		
		// initialize event listeners after setting stage properties:
		var fsListener:Object = new Object();
		fsListener.onFullScreen = Delegate.create(this, onFullscreen);
		Stage.addListener(fsListener);
		
		keyListener = new Object();
		AsBroadcaster.initialize(keyListener);
		keyListener.onKeyDown = function() {
			Stage['displayState'] = Stage['displayState'] == 'normal' ? 'fullScreen' : 'normal';
		};
		Key.addListener(keyListener);
		
		if (ExternalInterface.available) {
			initCallbacks();
		}
		else {
			setState(EI_ERROR);
			return;
		}
		
		playerID     = _root.playerID;
		secureDomain = (_root.secureDomain == undefined) ? "" : _root.secureDomain;
		if (secureDomain != "")
			System.security.allowDomain(secureDomain);
		defaultVolume    = (_root.volume == undefined)   ? undefined : _root.volume;
		initialVideoPath = (_root.initialVideoPath == undefined) ? "" : _root.initialVideoPath;
		
		if (!playerID) return;
		
		if (NOSKIN) {
			_global['setTimeout'](initDelegate, 0);
		}
		else {
			callLater('init');
		}
	}
	
	private function init():Void {
		sendEvent('init', {state: 1, sandboxType: System.security.sandboxType});
	}
	
	private function removePlayheadUpdateInt():Void {
		clearInterval(_playheadUpdateInt);
		delete _playheadUpdateInt;
	}
	
	// START JS communication methods.
	// These methods are responsible for communication in and out with the FAVideo Javascript object.
	/*
	 * @private
	 * 
	 */
	private function sendNewPlayerState(event:Object):Void {
		var newState:Object = { };
		var dirty:Boolean   = false;
		
		for (var n:String in currentState) {
			var val:Object = currentState[n];
			if (this[val.prop] == null) { continue; }
			if (val.value === undefined || val.value != this[val.prop]) {
				newState[n] = this[val.prop];
				val.value = this[val.prop];
				dirty = true;
			}
		}
		
		if (dirty) {
			callJS('update', newState);
		}
	}
	
	public function callMethod():Void {
		var method:String = String(arguments.shift());
		sendEvent('debug', {msg: 'received dispatch from JS: ' + method});
		this[method].apply(this, arguments);
	}
	
	/*
	//Events
		cuePoint //infoObject
		metaData //infoObject
		progress //{bytesLoaded:25, bytesTotal:25}
		playheadUpdate //Dispatched when the playhead updates, based on the playheadUpdate property.
		complete
		ready
		stateChange //The state property will update before this event is fired.
	*/
	private function sendEvent(event:String, object:Object):Void {
		if (!playerID) return;
		if (event == 'debug' && !DEBUG)
			return;
		ExternalInterface.call('jpf.flash.callMethod', playerID, 'event', event, object);
	}
	
	private function callJS(method:String, data:Object) {
		if (!playerID) return;
		ExternalInterface.call('jpf.flash.callMethod', playerID, method, data);
	}
	
	private function initCallbacks():Void {
		ExternalInterface.addCallback('callMethod', this, callMethod);
	}
	
	private function sendPlayheadUpdate():Void {
		sendNewPlayerState();
		
		if (lastSentPlayheadTime == netStream.time) { return; } 
		sendEvent('playheadUpdate', {state:_state, playheadTime:netStream.time, totalTime:_totalTime});
		
		if (!NOSKIN)
			dispatchEvent({type:'playheadUpdate', playheadTime:netStream.time, totalTime:_totalTime}); //Event for the UIManager
		
		lastSentPlayheadTime = netStream.time;
	}
	// END JS communication methods.
	
	
	// START JS interface methods.
	// All of these methods are called (indirectly via callMethod) from the FAVideo object in Javascript.
	
	/**
	* @private
	* 
	* @deafult = false
	* 
	* Allows the user to click anywhere on the video to play/pause.
	* 
	*/
	private function setClickToTogglePlay(value:Boolean):Void {
		_clickToTogglePlay    = value;
		playPauseBtn._visible = value;
	}
	
	/**
	* @private
	* 
	* @default = true
	*/
	private function setAutoPlay(value:Boolean):Void {
		_autoPlay = value;
	}
	
	/**
	* @private
	* 
	* @default = 1
	*/
	private function setVolume(value:Number):Void {
		audioControl.setVolume(value);
		if (!NOSKIN)
			dispatchEvent({type:'volumeUpdate', volume:value}); //Event for the UIManager
	}
	
	/**
	* @private
	* 
	*/
	private function setTotalTime(value:Number):Void {
		_totalTime = value;
	}
	
	/**
	* @private
	* 
	*/
	private function setPlayheadTime(value:Number):Void {
		seek(value);
	}
	
	/**
	* @private
	* 
	* @default = .1
	*/
	private function setBufferTime(value:Number):Void {
		netStream.setBufferTime(value);
	}
	
	/**
	* @private
	* 
	* Possible Values are: maintainAspectRatio || exactFit || noScale
	*/
	private function setVideoScaleMode(value:String):Void {
		_videoScaleMode = value;
		if (NOSKIN) {
			_global['setTimeout'](resizeDelegate, 0);
		}
		else {
			callLater('onResize');
		}
	}
	
	/**
	* @private
	* 
	* Possible values are Defined in AlignModes
	*/
	private function setVideoAlign(value:String) {
		_videoAlign = value;
		if (NOSKIN) {
			_global['setTimeout'](resizeDelegate, 0);
		}
		else {
			callLater('onResize');
		}
	}
	
	/**
	* @private
	* 
	* @default = 250
	* 
	* A number that is the amount of time, in milliseconds, between each playheadUpdate event.
	*/
	private function setPlayheadUpdateInterval(value:Number):Void {
		_playheadUpdateInterval = value;
		
		removePlayheadUpdateInt();
		if (netStream) {
			_playheadUpdateInt = setInterval(this, 'sendPlayheadUpdate', _playheadUpdateInterval);
		}
	}
	
	/**
	* @private
	* 
	* Sets the theme color.
	* 
	*/
	private function setThemeColor(value:Number):Void {
		_themeColor = value;
		
		if (_themeColor) {
			var r:Number = (_themeColor & 0xff0000) >> 16;
			var g:Number = (_themeColor & 0x00ff00) >> 8;
			var b:Number = _themeColor & 0x0000ff;
			
			if (!NOSKIN) {
				var colorTrans:ColorTransform = new ColorTransform(0,0,0,1,r,g,b,0);
				uiManager.skin_mc.transform.colorTransform = colorTrans;
			}
		}
		else if (!NOSKIN) {
			uiManager.skin_mc.transform.colorTransform = null;
		}
		
	}
	
	/**
	* @private
	* 
	* @default = false
	* 
	*/
	private function setSkinAutoHide(value:Boolean):Void {
		_skinAutoHide = value;
		uiManager.skinAutoHide = value;
		
		if (!NOSKIN)
			uiManager.skin_mc._visible = !value && _skinVisible?true:uiManager.skin_mc._visible;
	}
	
	/**
	* @private
	* 
	*/
	private function loadSkin(url:String):Void {
		flvHeightOffset = 0;
		sendEvent('debug', {msg: 'skinLoading: ' + url}); 
		uiManager.skin = url;
	}
	
	
	/**
	 * Called from JS, when the size changes.
	 * To accommodate IE bug where the Stage.width = 0; when swf in placed in innerHTML.
	 * 
	 */
	private function setSize(width:Number, height:Number):Void {
		__width = Number(width);
		__height = Number(height);
		sendEvent('debug', {msg: 'setSize - adding callLater callback'});
		if (NOSKIN) {
			_global['setTimeout'](resizeDelegate, 0);
		}
		else {
			callLater('onResize');
		}
	}
	
	/**
	 * Called from JS, when fullscreen mode needs to be activated.
	 */
	private function setFullscreen(bFull:Boolean):Void {
		keyListener.broadcastMessage('onKeyDown');
		/*if (bFull)
			sendEvent('debug', {msg: 'going in to fullscreen mode: current: ' + Stage['displayState']});
		else
			sendEvent('debug', {msg: 'going in to normal mode: current: ' + Stage['displayState']});
		try {
			//Stage.displayState = bFull ? 'fullScreen' : 'normal';
			_global.handlerFullscreen(bFull);
			sendEvent('debug', {msg: 'fullscreen - displayState is now: ' + Stage['displayState']});
		} catch(e:Error) {
			sendEvent('debug', {msg: 'fullscreen error: ' + e.toString()});
		}*/
		//TODO add event listeners and resize the video to match fullscreen dims
	}
	
	private function onFullscreen(bFull:Boolean):Void {
		sendEvent('debug', {msg: 'fullscreen event incoming: ' + bFull});
		if (bFull) {
			setSize(Stage.width, Stage.height);
		}
		else {
			setSize(lastSize.width, lastSize.height);
		}
		sendEvent('fullscreen', {state: bFull});
	}
	
	private function onKeydown():Void {
		sendEvent('debug', {msg: 'onKeyDown event fired...'});
		Stage['displayState'] = Stage['displayState'] == 'normal' ? 'fullScreen' : 'normal';
	}
	
	/**
	* Called from JS on initilization.
	* Sets all the default properties.
	* Possible values are: "id", "clickToTogglePlay", "autoPlay", "volume", "bufferTime", "videoVideoScaleMode", "videoAlign", "playheadUpdateInterval"
	* This can be a delta packet
	*/
	private function update(packet:Object):Void {
		for (var n:String in packet) {
			this[jsPropMap[n]].call(this, packet[n]);
		}
		
		if (!_inited) {
			uiManager.skin_mc._visible = false;//true;
			_inited = true;
		}
	}
	
	private function setSkinVisible(value:Boolean):Void {
		_skinVisible = value;
		uiManager.visible = value;
	}
	
	private function setPreviewImagePath(value:String):Void {
		_previewImagePath = value;
		
		if (_previewImagePath) {
			previewImage.load(_previewImagePath);
		}
		else {
			previewImage.clear();
		}
		
		previewImage.visible = _state!=undefined?false:true;
	}
	// END JS interface methods
	
}