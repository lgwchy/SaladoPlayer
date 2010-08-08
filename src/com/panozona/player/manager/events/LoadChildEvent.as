﻿/*
Copyright 2010 Marek Standio.

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
along with SaladoPlayer.  If not, see <http://www.gnu.org/licenses/>.
*/
package com.panozona.player.manager.events{
		
	import flash.events.Event;	
	import com.panozona.player.manager.data.ChildData;
	
	
	/**
	 * ...
	 * @author mstandio
	 */
	public class LoadChildEvent extends Event {
		
		public static const BITMAPDATA_CONTENT:String =  "bitmapDataContent";		
		
		public var childData:ChildData;
			
		public function LoadChildEvent(type:String, childData:ChildData) {
			super(type);						
			this.childData = childData;
		}		
	}
}