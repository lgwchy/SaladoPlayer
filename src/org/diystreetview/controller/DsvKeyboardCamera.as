/*
Copyright 2011 Marek Standio.

This file is part of DIY streetview player.

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
package org.diystreetview.controller{
	
	import com.panosalado.controller.KeyboardCamera;
	import org.diystreetview.model.CameraKeyBindings;
	import flash.events.KeyboardEvent;
	import org.diystreetview.player.manager.DsvManager;
	
	public class DsvKeyboardCamera extends com.panosalado.controller.KeyboardCamera {
		override protected function keyDownEvent( event:KeyboardEvent ):void {
			switch(event.keyCode) {
				case CameraKeyBindings.FORWARD:
					(_viewData as DsvManager).clickForwardHotspot();
				break;
				
				case CameraKeyBindings.BACKWARD:
					(_viewData as DsvManager).clickBackwardHotspot();
				break;
				
				default:
					super.keyDownEvent(event);
			}
		}
	}
}