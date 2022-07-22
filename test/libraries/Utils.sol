// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.6.0 <0.8.0;

library Utils {
    function nearestUsableTick(int24 currentTick, int24 tickSpacing)
        public
        pure
        returns (int24)
    {
        if (currentTick == 0) {
            return 0;
        }
        int24 direction = (currentTick >= 0) ? int24(1) : -1;
        currentTick *= direction;

        int24 nearestTick = (currentTick % tickSpacing <= tickSpacing / 2)
            ? currentTick - (currentTick % tickSpacing)
            : currentTick + (tickSpacing - (currentTick % tickSpacing));
        nearestTick *= direction;
        return nearestTick;
    }
}
