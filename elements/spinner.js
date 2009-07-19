/*
 * See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 *
 */

// #ifdef __JSPINNER || __INC_ALL
/** 
 * This element is used to choosing number by plus/minus buttons.
 * When plus button is clicked longer, number growing up faster. The same
 * situation is for minus button. It's possible to increment and decrement
 * value by moving mouse cursor up or down with clicked input. Max and
 * min attributes define range with allowed values.
 * 
 * Example:
 * Spinner element with start value equal 6 and allowed values from range
 * (-100, 200)
 * <code>
 * <j:spinner value="6" min="-99" max="199"></j:spinner>
 * </code>
 * 
 * Example:
 * Sets the value based on data loaded into this component.
 * <code>
 * <j:spinner>
 *     <j:bindings>
 *         <j:value select="@value" />
 *     </j:bindings>
 * </j:spinner>
 * </code>
 * 
 * Example:
 * A shorter way to write this is:
 * <code>
 * <j:spinner ref="@value" />
 * </code>
 * 
 * Example:
 * Is showing usage of model in spinner connected with textbox
 * <code>
 * <j:model id="mdlTest">
 *     <overview page="1" pages="50" />
 * </j:model>
 * <j:spinner id="spinner" min="0" model="mdlTest">
 *     <j:bindings>
 *         <j:value select = "@page" />
 *         <j:max select   = "@pages" />
 *         <j:caption><![CDATA[{@page} of {@pages}, it's possible to add more text]]></j:caption>
 *     </j:bindings>
 * </j:spinner>
 * <j:textbox value="{spinner.caption}"></j:textbox>
 * </code>
 * 
 * @attribute {Number}   max       maximal allowed value, default is 64000
 * @attribute {Number}   min       minimal allowed value, default is -64000
 * @attribute {Number}   value     actual value displayed in component
 * 
 * @classDescription     This class creates a new spinner
 * @return {Spinner}     Returns a new spinner
 *
 * @author      
 * @version     %I%, %G%
 * 
 * @inherits apf.Presentation
 * @inherits apf.DataBinding
 * @inherits apf.Validation
 * @inherits apf.XForms
 *
 * @binding value  Determines the way the value for the element is retrieved 
 * from the bound data.
 */
apf.spinner = apf.component(apf.NODE_VISIBLE, function() {
    this.max           = 64000;
    this.min           = -64000;
    this.focused       = false;
    this.value         = 0;

    var _self     = this;

    this.$supportedProperties.push("width", "value", "max", "min", "caption");

    this.$propHandlers["value"] = function(value) {
        value = parseInt(value) || 0;

        if (value) {
            this.value = this.oInput.value = (value > _self.max
                ? _self.max
                : (value < _self.min
                    ? _self.min
                    : value));
        }
    };

    this.$propHandlers["min"] = function(value) {
        if (parseInt(value)) {
            this.min = parseInt(value);
            if (value > this.value) {
                this.change(value);
            }
        }
    };

    this.$propHandlers["max"] = function(value) {
        if (parseInt(value)) {
            this.max = parseInt(value);
            if(value < this.value) {
                this.change(value);
            }
        }
    };

    /* ********************************************************************
     PUBLIC METHODS
     *********************************************************************/

    /**
     * Sets the value of this element. This should be one of the values
     * specified in the values attribute.
     * @param {String} value the new value of this element
     */
    this.setValue = function(value) {
       this.setProperty("value", value);
    };

    /**
     * Returns the current value of this element.
     * @return {String}
     */
    this.getValue = function() {
        return this.value;
    };

    this.$enable = function() {
        this.oInput.disabled = false;
        this.$setStyleClass(this.oInput, "", ["inputDisabled"]);
    };

    this.$disable = function() {
        this.oInput.disabled = true;
        this.$setStyleClass(this.oInput, "inputDisabled");
    };

    this.$focus = function(e) {
        if (!this.oExt || this.disabled || this.focused)
            return;

        //#ifdef __WITH_WINDOW_FOCUS
        if (apf.hasFocusBug)
            apf.sanitizeTextbox(this.oInput);
        //#endif

        this.focused = true;
        this.$setStyleClass(this.oInput, "focus");
        this.$setStyleClass(this.oButtonPlus, "plusFocus");
        this.$setStyleClass(this.oButtonMinus, "minusFocus");
    };

    this.$blur = function(e) {
        if (!this.oExt && !this.focused)
            return;

        this.$setStyleClass(this.oInput, "", ["focus"]);
        this.$setStyleClass(this.oButtonPlus, "", ["plusFocus"]);
        this.$setStyleClass(this.oButtonMinus, "", ["minusFocus"]);
        this.focused = false;
    }

    /* ***********************
     Keyboard Support
     ************************/
    //#ifdef __WITH_KEYBOARD
    this.addEventListener("keydown", function(e) {
        var key = e.keyCode;

        var keyAccess = (key < 8 || (key > 8 && key < 37 && key !== 12)
                      || (key > 40 && key < 46) || (key > 46 && key < 48)
                      || (key > 57 && key < 96) || (key > 105 && key < 109)
                      || (key > 109 && key !== 189));

       if (keyAccess)
           return false;

    }, true);

    this.addEventListener("keyup", function(e) {
        this.setValue(this.oInput.value);
    }, true);
    //#endif
    
    /**
     * @event click     Fires when the user presses a mousebutton while over this element and then let's the mousebutton go. 
     * @event mouseup   Fires when the user lets go of a mousebutton while over this element. 
     * @event mousedown Fires when the user presses a mousebutton while over this element. 
     */
    this.$draw = function() {
        //Build Main Skin
        this.oExt = this.$getExternal(null, null, function(oExt) {
            oExt.setAttribute("onmousedown",
                'this.host.dispatchEvent("mousedown", {htmlEvent : event});');
            oExt.setAttribute("onmouseup",
                'this.host.dispatchEvent("mouseup", {htmlEvent : event});');
            oExt.setAttribute("onclick",
                'this.host.dispatchEvent("click", {htmlEvent : event});');
        });

        this.oInt         = this.$getLayoutNode("main", "container", this.oExt);
        this.oInput       = this.$getLayoutNode("main", "input", this.oExt);
        this.oButtonPlus  = this.$getLayoutNode("main", "buttonplus", this.oExt);
        this.oButtonMinus = this.$getLayoutNode("main", "buttonminus", this.oExt);

        //#ifdef __WITH_WINDOW_FOCUS
        apf.sanitizeTextbox(this.oInput);
        //#endif

        var timer, z = 0;

        /* Setting start value */
        this.oInput.value = this.value;

        this.oInput.onmousedown = function(e) {
            if (_self.disabled)
                return;
            
            e = e || window.event;

            var value = parseInt(this.value) || 0, step = 0,
                cy = e.clientY, cx = e.clientX,
                ot = _self.oInt.offsetTop, ol = _self.oInt.offsetLeft,
                ow = _self.oInt.offsetWidth, oh = _self.oInt.offsetHeight;

            clearInterval(timer);
            timer = setInterval(function() {
                if (!step)
                    return;

                if (value + step <= _self.max
                    && value + step >= _self.min) {
                    value += step;
                    _self.oInput.value= Math.round(value);
                }
                else {
                    _self.oInput.value = step < 0 
                        ? _self.min
                        : _self.max;
                }
            }, 10);

            document.onmousemove = function(e) {
                e = e || window.event;
                var y = e.clientY, x = e.clientX, nrOfPixels = cy - y;

                if ((y > ot && x > ol) && (y < ot + oh && x < ol + ow)) {
                    step = 0;
                    return;
                }

                step = Math.pow(Math.min(200, Math.abs(nrOfPixels)) / 10, 2) / 10;
                if (nrOfPixels < 0)
                    step = -1 * step;
            };

            document.onmouseup = function(e) {
                clearInterval(timer);

                var value = parseInt(_self.oInput.value);

                if (value != _self.value) {
                    _self.change(value);
                }
                document.onmousemove = null;
            };
        };

        /* Fix for mousedown for IE */
        var buttonDown = false;
        this.oButtonPlus.onmousedown = function(e) {
            if (_self.disabled)
                return;
            
            e = e || window.event;
            buttonDown = true;

            var value = (parseInt(_self.oInput.value) || 0) + 1;

            apf.setStyleClass(_self.oButtonPlus, "plusDown", ["plusHover"]);

            clearInterval(timer);
            timer = setInterval(function() {
                z++;
                value += Math.pow(Math.min(200, z) / 10, 2) / 10;
                value = Math.round(value);

                _self.oInput.value = value <= _self.max
                    ? value
                    : _self.max;
            }, 50);
        };

        this.oButtonMinus.onmousedown = function(e) {
            if (_self.disabled)
                return;
            
            e = e || window.event;
            buttonDown = true;

            var value = (parseInt(_self.oInput.value) || 0) - 1;

            apf.setStyleClass(_self.oButtonMinus, "minusDown", ["minusHover"]);

            clearInterval(timer);
            timer = setInterval(function() {
                z++;
                value -= Math.pow(Math.min(200, z) / 10, 2) / 10;
                value = Math.round(value);

                _self.oInput.value = value >= _self.min
                    ? value
                    : _self.min;
            }, 50);
        };

        this.oButtonMinus.onmouseout = function(e) {
            if (_self.disabled)
                return;
            
            window.clearInterval(timer);
            z = 0;

            var value = parseInt(_self.oInput.value);

            if (value != _self.value) {
                _self.change(value);
            }
            apf.setStyleClass(_self.oButtonMinus, "", ["minusHover"]);

            if (!_self.focused) {
               _self.$blur(e);
            }
        };

        this.oButtonPlus.onmouseout  = function(e) {
            if (_self.disabled)
                return;
            
            window.clearInterval(timer);
            z = 0;

            var value = parseInt(_self.oInput.value);

            if (value != _self.value) {
                _self.change(value);
            }
            apf.setStyleClass(_self.oButtonPlus, "", ["plusHover"]);

            if (!_self.focused) {
               _self.$blur(e);
            }
        };

        this.oButtonMinus.onmouseover = function(e) {
            if (_self.disabled)
                return;
                
            apf.setStyleClass(_self.oButtonMinus, "minusHover");
        };

        this.oButtonPlus.onmouseover  = function(e) {
            if (_self.disabled)
                return;
                
            apf.setStyleClass(_self.oButtonPlus, "plusHover");
        };

        this.oButtonPlus.onmouseup = function(e) {
            if (_self.disabled)
                return;
            
            e = e || event;
            e.cancelBubble = true;

            apf.setStyleClass(_self.oButtonPlus, "plusHover", ["plusDown"]);

            window.clearInterval(timer);
            z = 0;

            var value = parseInt(_self.oInput.value);

            if (!buttonDown) {
                value++;
                _self.oInput.value = value;
            }
            else {
                buttonDown = false;
            }

            if (value != _self.value) {
                _self.change(value);
            }
        };

        this.oButtonMinus.onmouseup = function(e) {
            if (_self.disabled)
                return;
            
            e = e || event;
            e.cancelBubble = true;

            apf.setStyleClass(_self.oButtonMinus, "minusHover", ["minusDown"]);

            window.clearInterval(timer);
            z = 0;

            var value = parseInt(_self.oInput.value);

            if (!buttonDown) {
                value--;
                _self.oInput.value = value;
            }
            else {
                buttonDown = false;
            }


            if (value != _self.value) {
                _self.change(value);
            }
        };

        this.oInput.onselectstart = function(e) {
            e = e || event;
            e.cancelBubble = true;
        };

        this.oInput.host = this;
    };

    this.$loadAml = function(x) {
        apf.AmlParser.parseChildren(this.$aml, null, this);
    };

    this.$destroy = function() {
        this.oInput.onkeypress =
        this.oInput.onmousedown =
        this.oInput.onkeydown =
        this.oInput.onkeyup =
        this.oInput.onselectstart =
        this.oButtonPlus.onmouseover =
        this.oButtonPlus.onmouseout =
        this.oButtonPlus.onmousedown =
        this.oButtonPlus.onmouseup =
        this.oButtonMinus.onmouseover =
        this.oButtonMinus.onmouseout =
        this.oButtonMinus.onmousedown =
        this.oButtonMinus.onmouseup = null;
    };
}).implement(
    //#ifdef __WITH_DATABINDING
    apf.DataBinding,
    //#endif
    //#ifdef __WITH_VALIDATION
    apf.Validation,
    //#endif
    //#ifdef __WITH_XFORMS
    apf.XForms,
    //#endif
    apf.Presentation
);

// #endif
