import React from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Hexagon } from 'lucide-react';

export function Navbar() {
    return (
        <nav className="flex items-center justify-between px-6 py-4 border-b border-white/10 bg-fair-bg/80 backdrop-blur-md fixed w-full z-50">
            <div className="flex items-center gap-2">
                <Hexagon className="w-8 h-8 text-fair-primary" />
                <span className="text-xl font-bold tracking-wider text-white">FairDAO</span>
            </div>
            <div>
                <ConnectButton />
            </div>
        </nav>
    );
}
