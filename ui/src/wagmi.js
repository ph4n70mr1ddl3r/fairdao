import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { mainnet, optimism, arbitrum, sepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
    appName: 'FairDAO',
    projectId: 'YOUR_PROJECT_ID', // TODO: Replace with env var or user input
    chains: [mainnet, optimism, arbitrum, sepolia],
    ssr: false, // Client-side only for now
});
