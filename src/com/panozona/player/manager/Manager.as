﻿/*
Copyright 2011 Marek Standio.

This file is part of SaladoPlayer.

SaladoPlayer is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.

SaladoPlayer is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with SaladoPlayer. If not, see <http://www.gnu.org/licenses/>.
*/
package com.panozona.player.manager {
	
	import com.panosalado.controller.*;
	import com.panosalado.core.*;
	import com.panosalado.events.*;
	import com.panosalado.view.*;
	import com.panozona.player.*;
	import com.panozona.player.module.*;
	import com.panozona.player.module.utils.*;
	import com.panozona.player.manager.data.*;
	import com.panozona.player.manager.data.actions.*;
	import com.panozona.player.manager.data.panoramas.*;
	import com.panozona.player.manager.events.*;
	import com.panozona.player.manager.utils.*;
	import com.panozona.player.manager.utils.loading.*;
	import flash.display.*;
	import flash.events.*;
	import flash.utils.*;
	
	public class Manager extends PanoSalado{
		
		public const description:ModuleDescription = new ModuleDescription("SaladoPlayer", "1.0", "http://panozona.com/");
		
		/**
		 * Dictionary, where key is hotspotData object
		 * and value is loaded hotspot (DisplayObject)
		 */
		public var hotspots:Dictionary;
		
		protected var panoramaIsMoving:Boolean;
		protected var pendingActionId:String;
		protected var panoramaLoadingCanceled:Boolean; // czy to zostawic 
		
		protected var _managerData:ManagerData;
		protected var _saladoPlayer:SaladoPlayer; // parent needed to access loaded modules
		
		protected var _currentPanoramaData:PanoramaData; // hmmm czy tutja to powinno byc publczne 
		protected var _previousPanoramaData:PanoramaData; // to tak samo chyba nie powinno to tak wygladac 
		protected var arrListeners:Array;  // hold hotspots mouse event listeners so that they can be removed
		
		public function Manager() {
			description.addFunctionDescription("print", String);
			description.addFunctionDescription("loadPano", String);
			description.addFunctionDescription("moveToHotspot", String);
			description.addFunctionDescription("moveToHotspotThen", String, String);
			description.addFunctionDescription("moveToView", Number, Number, Number);
			description.addFunctionDescription("moveToViewThen", Number, Number, Number, String);
			description.addFunctionDescription("jumpToView", Number, Number, Number);
			description.addFunctionDescription("startMoving", Number, Number);
			description.addFunctionDescription("stopMoving");
			description.addFunctionDescription("advancedMoveToHotspot", String, Number, Number, Function);
			description.addFunctionDescription("advancedMoveToHotspotThen", String, Number, Number, Function, String);
			description.addFunctionDescription("advancedMoveToView", Number, Number, Number, Number, Function);
			description.addFunctionDescription("advancedMoveToViewThen", Number, Number, Number, Number, Function, String);
			description.addFunctionDescription("advancedStartMoving", Number, Number, Number, Number, Number);
			description.addFunctionDescription("runAction", String);
			if (stage) stageReady();
			else addEventListener(Event.ADDED_TO_STAGE, stageReady);
		}
		
		private function stageReady(e:Event = null):void {
			removeEventListener(Event.ADDED_TO_STAGE, stageReady);
			_saladoPlayer = SaladoPlayer(this.parent.root);
			_managerData = _saladoPlayer.managerData;
		}
		
		public override function initialize(dependencies:Array):void {
			super.initialize(dependencies);
			addEventListener(Event.COMPLETE, panoramaLoaded, false, 0, true);
		}
		
		public function get currentPanoramaData():PanoramaData {
			return _currentPanoramaData
		}
		
		public function loadFirstPanorama():void {
			if (_managerData.allPanoramasData.firstPanorama != null) {
				loadPanoramaById(_managerData.allPanoramasData.firstPanorama);
			}else {
				if (_managerData.panoramasData != null && _managerData.panoramasData.length > 0) {
					loadPanoramaById(_managerData.panoramasData[0].id);
				}
			}
		}
		
		public function loadPanoramaById(panoramaId:String):void {
			var panoramaData:PanoramaData = _managerData.getPanoramaDataById(panoramaId);
			if (panoramaData != null && !panoramaIsMoving && panoramaData !== _currentPanoramaData){
				if (!panoramaLoadingCanceled && _currentPanoramaData != null && _currentPanoramaData.onLeaveToAttempt[panoramaData.id] != null) {
					panoramaLoadingCanceled = true;
					runAction(_currentPanoramaData.onLeaveToAttempt[panoramaData.id]);
					return;
				}
				
				panoramaLoadingCanceled = false;
				_previousPanoramaData = _currentPanoramaData;
				_currentPanoramaData = panoramaData;
				panoramaIsMoving = true;
			
				if(_previousPanoramaData != null){
					runAction(_previousPanoramaData.onLeave);
					runAction(_previousPanoramaData.onLeaveTo[currentPanoramaData.id]);
				}
				
				Trace.instance.printInfo("loading: " + panoramaData.id + " (" + panoramaData.params.path + ")");
				
				for (var i:int = 0; i < _managedChildren.numChildren; i++ ) {
					for(var j:Number = 0; j < arrListeners.length; j++){
						if (_managedChildren.getChildAt(i).hasEventListener(arrListeners[j].type)) {
							_managedChildren.getChildAt(i).removeEventListener(arrListeners[j].type, arrListeners[j].listener);
						}
					}
				}
				dispatchEvent(new PanoramaEvent(PanoramaEvent.PANORAMA_STARTED_LOADING));
				super.loadPanorama(panoramaData.params.clone());
				loadHotspots(currentPanoramaData);
			}
		}
		
		protected function loadHotspots(panoramaData:PanoramaData):void {
			hotspots = new Dictionary();
			var hotspotsLoader:LoadablesLoader = new LoadablesLoader();
			hotspotsLoader.addEventListener(LoadLoadableEvent.LOST, hotspotLost);
			hotspotsLoader.addEventListener(LoadLoadableEvent.LOADED, hotspotLoaded);
			hotspotsLoader.addEventListener(LoadLoadableEvent.FINISHED, hotspotsFinished);
			hotspotsLoader.load(panoramaData.getHotspotsLoadable());
			for each(var hotspotDataFactory:HotspotDataFactory in panoramaData.getHotspotsFactory()) {
				// TODO: get form factory...
			}
		}
		
		protected function hotspotLost(event:LoadLoadableEvent):void {
			_saladoPlayer.traceWindow.printError("Could not load hotspot: " + event.loadable.path);
		}
		
		protected function hotspotLoaded(event:LoadLoadableEvent):void {
			var managedChild:ManagedChild;
			var hotspotData:HotspotData = (event.loadable as HotspotData);
			if (hotspotData is HotspotDataSwf) {
				if ("references" in (event.content as Object)) {
					try {(event.content as Object).references(_saladoPlayer, (hotspotData as HotspotDataSwf))} catch (e:Error){}
				}
				managedChild = new SwfHotspot(event.content as Sprite);
				managedChild.buttonMode = hotspotData.handCursor;
			}else {
				managedChild = new ImageHotspot(event.content as Bitmap);
				managedChild.buttonMode = hotspotData.handCursor;
			}
			
			if (hotspotData.mouse.onClick != null) {
				managedChild.addEventListener(MouseEvent.CLICK, getMouseEventHandler(hotspotData.mouse.onClick));
				arrListeners.push({type:MouseEvent.CLICK, listener:getMouseEventHandler(hotspotData.mouse.onClick)});
			}
			if (hotspotData.mouse.onPress != null) {
				managedChild.addEventListener(MouseEvent.MOUSE_DOWN, getMouseEventHandler(hotspotData.mouse.onPress));
				arrListeners.push({type:MouseEvent.MOUSE_DOWN, listener:getMouseEventHandler(hotspotData.mouse.onPress)});
			}
			if (hotspotData.mouse.onRelease != null) {
				managedChild.addEventListener(MouseEvent.MOUSE_UP, getMouseEventHandler(hotspotData.mouse.onRelease));
				arrListeners.push({type:MouseEvent.MOUSE_UP, listener:getMouseEventHandler(hotspotData.mouse.onRelease)});
			}
			if (hotspotData.mouse.onOver != null) {
				managedChild.addEventListener(MouseEvent.ROLL_OVER, getMouseEventHandler(hotspotData.mouse.onOver));
				arrListeners.push({type:MouseEvent.ROLL_OVER, listener:getMouseEventHandler(hotspotData.mouse.onOver)});
			}
			if (hotspotData.mouse.onOut != null) {
				managedChild.addEventListener(MouseEvent.ROLL_OUT, getMouseEventHandler(hotspotData.mouse.onOut));
				arrListeners.push({type:MouseEvent.ROLL_OUT, listener:getMouseEventHandler(hotspotData.mouse.onOut)});
			}
			
			var piOver180:Number = Math.PI / 180;
			var pr:Number = (-1 * (-hotspotData.location.pan - 90)) * piOver180;
			var tr:Number = -1 * hotspotData.location.tilt * piOver180;
			var xc:Number = hotspotData.location.distance * Math.cos(pr) * Math.cos(tr);
			var yc:Number = hotspotData.location.distance * Math.sin(tr);
			var zc:Number = hotspotData.location.distance * Math.sin(pr) * Math.cos(tr);
			
			managedChild.x = xc;
			managedChild.y = yc;
			managedChild.z = zc;
			managedChild.rotationY = (- hotspotData.location.pan  + hotspotData.transform.rotationY) * piOver180;
			managedChild.rotationX = (hotspotData.location.tilt + hotspotData.transform.rotationX) * piOver180;
			managedChild.rotationZ = hotspotData.transform.rotationZ * piOver180
			
			managedChild.scaleX = hotspotData.transform.scaleX;
			managedChild.scaleY = hotspotData.transform.scaleY;
			managedChild.scaleZ = hotspotData.transform.scaleZ;
			
			hotspots[hotspotData as HotspotData] = managedChild;
			addChild(managedChild);
		}
		
		private function getMouseEventHandler(id:String):Function{
			return function(e:MouseEvent):void {
				runAction(id);
			}
		}
		
		protected function hotspotsFinished(event:LoadLoadableEvent):void {
			event.target.removeEventListener(LoadLoadableEvent.LOST, hotspotLost);
			event.target.removeEventListener(LoadLoadableEvent.LOADED, hotspotLoaded);
			event.target.removeEventListener(LoadLoadableEvent.FINISHED, hotspotsFinished);
			dispatchEvent(new PanoramaEvent(PanoramaEvent.HOTSPOTS_LOADED));
		}
		
		protected function panoramaLoaded(e:Event):void {
			arrListeners = new Array();
			panoramaIsMoving = false;
			runAction(currentPanoramaData.onEnter);
			if (_previousPanoramaData != null ){
				runAction(currentPanoramaData.onEnterFrom[_previousPanoramaData.id]);
			}
			dispatchEvent(new PanoramaEvent(PanoramaEvent.PANORAMA_LOADED));
		}
		
		protected function transitionComplete(e:Event):void {
			runAction(currentPanoramaData.onTransitionEnd);
			if(_previousPanoramaData != null){
				runAction(currentPanoramaData.onTransitionEndFrom[_previousPanoramaData.id]);
			}
			dispatchEvent(new PanoramaEvent(PanoramaEvent.TRANSITION_ENDED));
		}
		
		protected function swingComplete(e:PanoSaladoEvent):void {
			removeEventListener(PanoSaladoEvent.SWING_TO_CHILD_COMPLETE, swingComplete);
			removeEventListener(PanoSaladoEvent.SWING_TO_COMPLETE, swingComplete);
			panoramaIsMoving = false;
			if (pendingActionId != null) {
				runAction(pendingActionId);
			}
		}
		
///////////////////////////////////////////////////////////////////////////////
//  Exposed functions 
///////////////////////////////////////////////////////////////////////////////
		
		public function runAction(actionId:String):void {
			var actionData:ActionData = _managerData.getActionDataById(actionId);
			if (actionData == null) {
				if (actionId != null) Trace.instance.printWarning("Action not found: " + actionId);
				return;
			}
			for each(var functionData:FunctionData in actionData.functions) {
				try{
					if (functionData.owner == description.name) {
						if (description.functionsDescription[functionData.name] != undefined){
							(this[functionData.name] as Function).apply(this, functionData.args);
						}else {
							_saladoPlayer.traceWindow.printError("Unknown function: " + functionData.owner + "." + functionData.name);
						}
					}else{
						(_saladoPlayer.getModuleByName(functionData.owner) as Object).execute(functionData);
					}
				}catch (error:Error) {
					_saladoPlayer.traceWindow.printError("Could not execute " + functionData.owner + "." + functionData.name + ": " + error.message);
				}
			}
		}
		
		public function print(value:String):void {
			_saladoPlayer.traceWindow.printInfo(value);
		}
		
		public function loadPano(panramaId:String):void {
			loadPanoramaById(panramaId);
		}
		
		public function moveToHotspot(hotspotId:String):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = null;
			addEventListener(PanoSaladoEvent.SWING_TO_CHILD_COMPLETE, swingComplete);
			swingToChild(hotspots[currentPanoramaData.hotspotDataById(hotspotId)]);
		}
		
		public function moveToHotspotThen(hotspotId:String, actionId:String):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = actionId; 
			addEventListener(PanoSaladoEvent.SWING_TO_CHILD_COMPLETE, swingComplete);
			swingToChild(hotspots[currentPanoramaData.hotspotDataById(hotspotId)]);
		}
		
		public function moveToView(pan:Number, tilt:Number, fieldOfView:Number):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = null;
			addEventListener(PanoSaladoEvent.SWING_TO_COMPLETE, swingComplete);
			swingTo(pan, tilt, fieldOfView);
		}
		
		public function moveToViewThen(pan:Number, tilt:Number, fieldOfView:Number, actionId:String):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = actionId;
			addEventListener(PanoSaladoEvent.SWING_TO_COMPLETE, swingComplete);
			swingTo(pan, tilt, fieldOfView);
		}
		
		public function jumpToView(pan:Number, tilt:Number, fieldOfView:Number):void {
			if (panoramaIsMoving) return;
			renderAt(pan, tilt, fieldOfView);
		}
		
		public function startMoving(panSpeed:Number, tiltSpeed:Number):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			startInertialSwing(panSpeed, tiltSpeed);
		}
		
		public function stopMoving():void {
			panoramaIsMoving = false;
			stopInertialSwing();
		}
		
		public function advancedMoveToHotspot(hotspotId:String, fieldOfView:Number, speed:Number, tween:Function):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = null;
			addEventListener(PanoSaladoEvent.SWING_TO_CHILD_COMPLETE, swingComplete);
			swingToChild(hotspots[currentPanoramaData.hotspotDataById(hotspotId)], fieldOfView, speed, tween);
		}
		
		public function advancedMoveToHotspotThen(hotspotId:String, fieldOfView:Number, speed:Number, tween:Function, actionId:String):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = actionId;
			addEventListener(PanoSaladoEvent.SWING_TO_CHILD_COMPLETE, swingComplete);
			swingToChild(hotspots[currentPanoramaData.hotspotDataById(hotspotId)], fieldOfView, speed, tween);
		}
		
		public function advancedMoveToView(pan:Number, tilt:Number, fieldOfView:Number, speed:Number, tween:Function):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = null;
			addEventListener(PanoSaladoEvent.SWING_TO_COMPLETE, swingComplete);
			swingTo(pan, tilt, fieldOfView, speed, tween);
		}
		
		public function advancedMoveToViewThen(pan:Number, tilt:Number, fieldOfView:Number, speed:Number, tween:Function, actionId:String):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			pendingActionId = actionId;
			addEventListener(PanoSaladoEvent.SWING_TO_COMPLETE, swingComplete);
			swingTo(pan, tilt, fieldOfView, speed, tween);
		}
		
		public function advancedStartMoving(panSpeed:Number, tiltSpeed:Number, sensitivity:Number, friction:Number, threshold:Number):void {
			if (panoramaIsMoving) return;
			panoramaIsMoving = true;
			startInertialSwing(panSpeed, tiltSpeed, sensitivity, friction, threshold);
		}
	}
}