-[ MIX ]-----------------------------------------------------------------------

An MSX1 game that is heavily inspired by Taito's QIX.

This game is freeware, (c) 2022 Uninteresting

You can find me on msx.org

Version 2022-05-  .


-[ GAMEPLAY ]------------------------------------------------------------------

In Mix, you cordon off pieces of the playing field. You may move only on the
border of the open area, unless you are drawing a new line.

If the red enemies circling the playing field hit you, you're done for.
If the big green monster in the middle touches an open line you're still
drawing, you're done for.
If the time runs out, you're done for.

It's fine if the big monster touches you, mind you.

When enough of the playing field has been cordoned off, the scene is cleared.


-[ SCORING ]-------------------------------------------------------------------

You gain points by cordoning off area.

If you manage to leave one of the Tracers outside, you will gain bonus points
and the enemy will respawn after a short period.

If there are multiple big green enemies in the level, then separating them with
a line will:
 1) clear the level as if you had painted 100% of the level
 2) double the time bonus in that level


-[ CONTROLS ]------------------------------------------------------------------

You can move only on the edge of the open area. When you press FIRE and push
away from the edge, you will start drawing a new line. You may not loop back
to the unfinished line.

Unlike in Qix, the line drawing speed is constant.


-[ DISCLAIMER ]----------------------------------------------------------------

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


-[ CREDITS ]-------------------------------------------------------------------

Original game concept: Taito.

Coding: Uninteresting
Graphics: Uninteresting
Sound: Uninteresting


-[ VERSION HISTORY ]-----------------------------------------------------------

2022-05-   : Restored the shaded backgrounds

2022-05-05 : Fixed time bonus (x5 normally, x10 when defeating a main enemy)
             Main enemies can now move diagonally.
             Fixed coverage computation.
             Fixed bug with areas that share only one pixel (a corner).
             Changed all backgrounds to plain white to disallow drawing into the
                 painted area.
             Fixed exterior border check for when starting to draw.
             Minor GFX upgrades/bugfixes.

2022-04-23 : First version submitted to MSXdev'22

