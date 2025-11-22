import React from 'react';
import { Navbar } from './Navbar';
import { Footer } from './Footer';

export function Layout({ children }) {
    return (
        <div className="min-h-screen flex flex-col bg-fair-bg text-fair-text relative overflow-hidden">
            {/* Background Effects */}
            <div className="absolute top-0 left-1/4 w-96 h-96 bg-fair-secondary/20 rounded-full blur-[128px] pointer-events-none" />
            <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-fair-primary/10 rounded-full blur-[128px] pointer-events-none" />

            <Navbar />
            <main className="flex-grow pt-20 px-4 container mx-auto">
                {children}
            </main>
            <Footer />
        </div>
    );
}
