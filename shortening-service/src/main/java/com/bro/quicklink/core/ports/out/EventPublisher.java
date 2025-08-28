package com.bro.quicklink.core.ports.out;

/**
 * This is an Output Port. It defines the contract for any adapter that
 * needs to publish domain events.
 */
public interface EventPublisher {

    void publishUrlCreatedEvent(Object event);
}